const express = require("express"), multer = require("multer"), PDF = require("pdfkit");
const { ethers } = require("ethers"), fs = require("fs"), crypto = require("crypto");

const ADMIN_KEY = process.env.ADMIN_KEY || "admin";
// Hardhat node account #0 = the university wallet (demo key, public)
const KEY = process.env.PRIVATE_KEY || "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const provider = new ethers.JsonRpcProvider(process.env.RPC || "http://127.0.0.1:8545");
const abi = require("./artifacts/contracts/DocRegistry.sol/DocRegistry.json").abi;
const reg = new ethers.Contract(require("./deployment.json").address, abi, new ethers.NonceManager(new ethers.Wallet(KEY, provider)));

// off-chain store: student info + cert metadata (never on-chain)
fs.mkdirSync("pdfs", { recursive: true });
const DB = "db.json";
const db = fs.existsSync(DB) ? JSON.parse(fs.readFileSync(DB)) : { students: {}, certs: {} };
const save = () => fs.writeFileSync(DB, JSON.stringify(db, null, 1));
const sha = (buf) => "0x" + crypto.createHash("sha256").update(buf).digest("hex");

const app = express();
app.use(express.json(), express.static("public"));
const up = multer({ limits: { fileSize: 10e6 } });
const wrap = (f) => (q, s) => f(q, s).catch((e) => s.status(400).json({ error: e.shortMessage || e.message }));
const admin = (q, s, n) => (q.get("x-admin-key") === ADMIN_KEY ? n() : s.status(401).json({ error: "admin key" }));
const student = (q) => {
  const st = db.students[q.body?.studentId ?? q.query.studentId];
  const pin = q.body?.pin ?? q.query.pin;
  if (!st || st.pin !== pin) throw new Error("bad student id/pin");
};

// ---- University admin ----
app.post("/admin/students", admin, wrap(async (q, s) => {
  const { studentId, name, pin } = q.body;
  if (!studentId || !name || !pin) throw new Error("studentId, name, pin required");
  db.students[studentId] = { name, pin }; save(); s.json({ ok: true });
}));

async function issueCert(studentId, title, upload) {
  const st = db.students[studentId];
  if (!st || !title) throw new Error("unknown student or missing title");
  const certId = ethers.hexlify(crypto.randomBytes(32));
  if (upload && upload.subarray(0, 4).toString() !== "%PDF") throw new Error("the uploaded file is not a PDF");
  const doc = new PDF(), bufs = [];
  doc.on("data", (b) => bufs.push(b));
  const done = new Promise((r) => doc.on("end", r));
  doc.fontSize(24).text("University Certificate", { align: "center" }).moveDown()
    .fontSize(16).text(title, { align: "center" }).moveDown()
    .text(`Awarded to: ${st.name} (${studentId})`, { align: "center" }).moveDown()
    .fontSize(10).text(`Certificate ID: ${certId}`, { align: "center" })
    .text(`Issued: ${new Date().toISOString()}`, { align: "center" });
  doc.end(); await done;
  const pdf = upload || Buffer.concat(bufs); // the university's own PDF if one was attached
  const tx = await (await reg.issue(certId, sha(pdf))).wait();
  fs.writeFileSync(`pdfs/${certId}.pdf`, pdf);
  db.certs[certId] = { studentId, title }; save();
  return { certId, pdf, tx: tx.hash };
}

app.post("/admin/issue", admin, up.single("file"), wrap(async (q, s) => {
  const { certId } = await issueCert(q.body.studentId, q.body.title, q.file?.buffer);
  s.json({ certId });
}));

app.post("/admin/revoke", admin, wrap(async (q, s) => {
  await (await reg.revoke(q.body.certId)).wait(); s.json({ ok: true });
}));

// Scripted walkthrough for demos: register -> issue -> verify -> tamper -> revoke -> verify
app.post("/demo", admin, wrap(async (q, s) => {
  const steps = [], add = (title, text, status, extra = {}) => steps.push({ title, text, status, ...extra });
  const verdict = async (buf) => { const [ok, , d] = await reg.verify(sha(buf)); return result(ok, d).status; };

  const studentId = "DEMO" + Date.now().toString().slice(-5);
  db.students[studentId] = { name: "Demo Student", pin: "0000" }; save();
  add("University registers a student", `${studentId} (PIN 0000) is stored off-chain. No student data goes on the blockchain.`, "info");

  const { certId, pdf, tx } = await issueCert(studentId, "B.Sc. Computer Science (Demo)");
  add("University issues a certificate", "A PDF is generated and its SHA-256 fingerprint is recorded in the smart contract.", "info",
    { hash: sha(pdf), certId, tx });

  add("Employer verifies the original PDF", "The uploaded file's hash is found on the chain and the certificate is not revoked.", await verdict(pdf));

  const fake = Buffer.concat([pdf, Buffer.from("\n% grade changed")]);
  add("Employer verifies a tampered copy", "One edited line changes the hash completely, so the chain has no record of it.", await verdict(fake), { hash: sha(fake) });

  const rtx = await (await reg.revoke(certId)).wait();
  add("University revokes the certificate", "The revoked flag is set on the chain. The record itself is kept for audit.", "info", { tx: rtx.hash });

  add("Employer verifies the original again", "Same file, same hash, but its status is now revoked.", await verdict(pdf));
  s.json({ steps, certId, studentId });
}));

// ---- Audit ----
app.get("/admin/audit", admin, wrap(async (q, s) => {
  const ev = [...await reg.queryFilter(reg.filters.Issued()), ...await reg.queryFilter(reg.filters.Revoked())]
    .sort((a, b) => a.blockNumber - b.blockNumber || a.index - b.index);
  s.json(await Promise.all(ev.map(async (e) => ({
    event: e.fragment.name, certId: e.args.id, block: e.blockNumber, tx: e.transactionHash,
    time: (await e.getBlock()).timestamp,
  }))));
}));

// ---- Student ----
app.post("/student/certs", wrap(async (q, s) => {
  student(q);
  s.json(await Promise.all(Object.entries(db.certs).filter(([, c]) => c.studentId === q.body.studentId)
    .map(async ([certId, c]) => ({ certId, title: c.title, revoked: (await reg.docs(certId)).revoked }))));
}));
app.get("/student/download/:certId", wrap(async (q, s) => {
  student(q);
  const c = db.certs[q.params.certId];
  if (!c || c.studentId !== q.query.studentId) throw new Error("not your certificate");
  s.download(`pdfs/${q.params.certId}.pdf`);
}));

// ---- Employer / verification: returns no student info ----
const result = (exists, d) => !exists ? { status: "NOT_FOUND", message: "Altered, unregistered or invalid document" }
  : { status: d.revoked ? "REVOKED" : "AUTHENTIC", issuer: d.issuer, issuedAt: Number(d.issuedAt) };

app.post("/verify", up.single("file"), wrap(async (q, s) => {
  if (!q.file) throw new Error("file required");
  const [exists, , d] = await reg.verify(sha(q.file.buffer));
  s.json(result(exists, d));
}));
app.get("/verify/:certId", wrap(async (q, s) => {
  const d = await reg.docs(q.params.certId);
  s.json(result(d.issuedAt !== 0n, d));
}));

app.listen(3000, () => console.log("http://localhost:3000"));
