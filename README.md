# Blockchain Document Verification

> A university certificate verification system built on a blockchain smart contract. Employers can verify any certificate PDF in one second — tampered documents are mathematically impossible to fake.

---

## The Problem

Academic certificate fraud is a widespread and growing problem. Students can:
- **Edit or Photoshop** a PDF to change their grade or result.
- **Create a fake certificate** from scratch using a real template.
- Submit a **revoked/withdrawn** certificate the university has already cancelled.

Employers have **no trustworthy way** to confirm authenticity without calling the university — which is slow, error-prone, and doesn't scale.

---

## The Solution — In One Line

> Store a tamper-proof fingerprint of every certificate on a blockchain. Anyone can instantly verify any PDF by uploading it.

The document itself is **never stored on the blockchain** — only a SHA-256 cryptographic hash (fingerprint) of it is. This means:
- ✅ Student privacy is fully preserved
- ✅ Verification is instant and automated
- ✅ Any tampering — even one changed character — makes the hash different and the verification fails

---

## How It Works

```
University Admin
    │
    ├─ Registers student (name, ID, PIN) → stored locally (never on-chain)
    │
    └─ Issues certificate
          ├─ Generates a PDF
          ├─ Computes SHA-256 hash of the PDF
          └─ Writes (certId → hash) to the smart contract on the blockchain
                          │
                          ▼
                  🔗 Blockchain (immutable)
                          │
                          ▼
Employer uploads PDF
    ├─ Server computes SHA-256 of uploaded file
    └─ Queries blockchain:
          ├─ Hash found + not revoked  → ✅ AUTHENTIC
          ├─ Hash found + revoked      → ⚠️  REVOKED
          └─ Hash not found            → ❌ ALTERED / FAKE / UNREGISTERED
```

**Why is this tamper-proof?**
SHA-256 is a one-way cryptographic hash function. Change even a single byte in a PDF — one pixel, one letter, one invisible space — and the hash changes completely. Since the blockchain stores the original hash permanently, **any modified copy will always fail verification. It is mathematically guaranteed.**

---

## Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| Smart Contract | Solidity 0.8.24 | Stores, verifies, and revokes certificate hashes on-chain |
| Blockchain (local) | Hardhat Network | Local Ethereum-compatible blockchain for development and demo |
| Backend | Node.js + Express | REST API bridging the web UI and the blockchain |
| PDF Hashing | Node.js `crypto` (SHA-256) | Creates the fingerprint of each PDF |
| PDF Generation | PDFKit | Generates university certificates as real PDFs |
| File Uploads | Multer | Handles PDF uploads from the browser |
| Web Interface | Vanilla HTML/CSS/JS | Single-page app with dark/light mode — no framework |
| Contract Library | ethers.js v6 | JavaScript interface to communicate with the Ethereum contract |
| Testing | Hardhat + Mocha + Chai | Automated smart contract unit tests |
| Launcher | PowerShell + Batch | One-click start and stop for Windows |

---

## Project Structure

```
blockchain-document/
│
├── contracts/
│   └── DocRegistry.sol       ← The smart contract (core of the system)
│
├── scripts/
│   └── deploy.js             ← Deploys the contract to the local blockchain
│
├── public/
│   └── index.html            ← Complete web interface (single-page app)
│
├── test/
│   └── DocRegistry.js        ← Automated test: issue, verify, tamper, revoke
│
├── server.js                 ← Node.js/Express backend REST API
├── hardhat.config.js         ← Hardhat blockchain configuration
├── package.json              ← Project dependencies
│
├── start.bat                 ← One-click Windows launcher (double-click to run)
├── start.ps1                 ← PowerShell automation script
└── stop.bat                  ← Stops all running services
```

---

## The Smart Contract — `DocRegistry.sol`

The heart of the system. Deployed once per university. Stores four fields per certificate — no student personal data ever touches the blockchain:

| Field | Type | Meaning |
|---|---|---|
| `hash` | `bytes32` | SHA-256 fingerprint of the PDF |
| `issuer` | `address` | Blockchain wallet address of the university |
| `issuedAt` | `uint64` | Unix timestamp of issuance |
| `revoked` | `bool` | Whether the university has revoked this certificate |

**Functions:**
- `issue(id, hash)` — University records a new certificate fingerprint on-chain
- `revoke(id)` — University marks a certificate as revoked
- `verify(hash)` — Anyone checks if a hash exists on-chain and its current status

**Security guarantees built in:**
- `onlyOwner` modifier: only the university wallet can issue or revoke
- Duplicate prevention: same certId or hash cannot be issued twice
- Immutability: recorded hashes can never be deleted or changed
- Audit events: every `issue` and `revoke` emits a blockchain event with a permanent timestamp

---

## Backend API — `server.js`

### University Admin (requires `x-admin-key: admin` header)

| Endpoint | Action |
|---|---|
| `POST /admin/students` | Register a student (name, ID, PIN) — stored locally |
| `POST /admin/issue` | Generate a certificate PDF, hash it, write the hash to blockchain |
| `POST /admin/revoke` | Call the smart contract's `revoke()` function |
| `GET /admin/audit` | Retrieve the full blockchain event log |

### Student (requires studentId + PIN)

| Endpoint | Action |
|---|---|
| `POST /student/certs` | List the student's certificates and their blockchain status |
| `GET /student/download/:certId` | Download the original issued PDF |

### Public Verification (no authentication required)

| Endpoint | Action |
|---|---|
| `POST /verify` | Upload any PDF — server hashes it and checks the blockchain |
| `GET /verify/:certId` | Look up a certificate by ID directly on-chain |

### Demo

| Endpoint | Action |
|---|---|
| `POST /demo` | Auto-runs the full scenario: register → issue → verify → tamper → revoke → verify |

---

## Web Interface

A single-page app at `http://localhost:3000` with four role-based tabs:

| Tab | Who Uses It | What They Can Do |
|---|---|---|
| **University** | Admin | Register students, issue/revoke certificates, view audit log |
| **Student** | Student | View certificates, download PDFs |
| **Verify** | Employer | Upload a PDF or enter a cert ID to verify authenticity |
| **Demo** | Presenter | One button runs the full 6-step scenario with visual results |

---

## Demo Scenario

The built-in Demo tab auto-runs six steps:

| Step | Action | Result |
|---|---|---|
| 1 | University registers a demo student | Student ID created, stored locally |
| 2 | University issues a B.Sc. certificate | PDF generated, hash written to blockchain |
| 3 | Employer verifies the original PDF | ✅ AUTHENTIC |
| 4 | "Hacker" tampers with the PDF (one line appended) | ❌ NOT FOUND — hash is completely different |
| 5 | University revokes the certificate | Revoke transaction confirmed on-chain |
| 6 | Employer verifies the original again | ⚠️ REVOKED |

All three security scenarios proven in under 10 seconds.

---

## Privacy & Data Architecture

A critical design principle is separation of concerns:

**On-chain (blockchain — public and immutable):**
- `certificate_id → hash`
- `certificate_id → issuer address`
- `certificate_id → timestamp`
- `certificate_id → revoked status`

**Off-chain (local server — private):**
- Student name
- Student PIN
- Certificate title
- PDF files on disk

> **No student personal data ever touches the blockchain.** Only cryptographic hashes and certificate IDs are stored on-chain. The link between a hash and a student exists only in the university's private local database.

---

## Automated Tests — `test/DocRegistry.js`

`npm test` runs the Hardhat test suite against the smart contract directly:

| Test Case | Verified |
|---|---|
| Issue a certificate | Hash stored, `exists = true` |
| Verify original hash | Returns authentic |
| Verify a tampered hash | Returns `exists = false` |
| Duplicate issue rejected | Throws `"id exists"` |
| Non-university trying to revoke | Throws `"not university"` |
| Revoke certificate | `revoked = true` |
| Audit event emitted | `Issued` event logged |

All 7 scenarios pass in a single test. ✅

---

## Quick Start (One-Click)

On Windows, simply double-click:
- **`start.bat`** — Automatically checks dependencies, boots the local blockchain node, deploys the smart contract, launches the server, and opens `http://localhost:3000` in your browser.
- **`stop.bat`** — Shuts down any running services on ports 8545 and 3000.

**Admin key:** `admin`

### Manual Start

```bash
npm install
npx hardhat node                          # Terminal 1: local blockchain
npm run deploy && npm start               # Terminal 2: deploy + start server
# Open http://localhost:3000
```

`npm test` runs the smart contract test suite.

---

## Limitations (Current Scope)

| Limitation | Explanation |
|---|---|
| Local blockchain only | Runs on Hardhat node, not deployed to a public network |
| Demo-grade auth | Single shared admin key — a real system would need proper login |
| Public test wallet | Uses Hardhat's pre-funded test account — never use on a real network |
| Local PDF storage | PDFs stored on the server's disk, not a distributed file system |
| Single institution | Contract is owned by one deployer (the university) |

---

## Production Roadmap

1. Deploy smart contract to a public Ethereum testnet (e.g. Sepolia) or a private consortium chain
2. Replace demo authentication with institutional SSO / OAuth login
3. Store PDFs on IPFS (decentralised file storage)
4. Build a public verification portal — accessible by anyone without login
5. Multi-institution support with role-based contract ownership

---

## Notes

Demo-grade authentication: one shared admin key and per-student PINs. The server uses Hardhat's public test account #0 as the university wallet — never use that private key on a real network.
