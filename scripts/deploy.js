const { ethers } = require("hardhat");
const fs = require("fs");
(async () => {
  const r = await (await ethers.getContractFactory("DocRegistry")).deploy();
  await r.waitForDeployment();
  fs.writeFileSync("deployment.json", JSON.stringify({ address: await r.getAddress() }));
  console.log("DocRegistry at", await r.getAddress());
})();
