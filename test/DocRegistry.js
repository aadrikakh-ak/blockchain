const { expect } = require("chai");
const { ethers } = require("hardhat");

it("issue, verify, tamper, revoke, access control", async () => {
  const [uni, other] = await ethers.getSigners();
  const r = await (await ethers.getContractFactory("DocRegistry")).deploy();
  const id = ethers.id("cert1"), h = ethers.id("pdf bytes");
  await r.issue(id, h);
  let [ok, gotId, d] = await r.verify(h);
  expect(ok).to.equal(true); expect(gotId).to.equal(id); expect(d.revoked).to.equal(false);
  expect((await r.verify(ethers.id("tampered")))[0]).to.equal(false);
  await expect(r.issue(id, ethers.id("x"))).to.be.revertedWith("id exists");
  await expect(r.connect(other).revoke(id)).to.be.revertedWith("not university");
  await r.revoke(id);
  expect((await r.verify(h))[2].revoked).to.equal(true);
  expect(await r.queryFilter(r.filters.Issued())).to.have.length(1);
});
