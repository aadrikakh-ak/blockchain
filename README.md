# Blockchain Document Verification

University certificates are issued as PDFs. Only the SHA-256 hash, certificate ID, issuer and status go on a smart contract (never the document or student data). An employer verifies by uploading a PDF or entering a certificate ID:

- match and not revoked: **authentic**
- match and revoked: **revoked**
- no match: **altered, unregistered or invalid**

Modules: University admin, Student, Document verification, Smart contract (`contracts/DocRegistry.sol`), Employer, Audit (contract events).

## Run

    npm install
    npx hardhat node                 # terminal 1: local chain
    npm run deploy && npm start      # terminal 2: deploy contract, start server
    # open http://localhost:3000     (admin key: admin)

Open the **Demo** tab and click *Run demo scenario* for a guided walkthrough (issue, verify, tamper, revoke, verify).

`npm test` runs the contract test.

## Notes

Demo-grade auth: one shared admin key and per-student PINs. The server uses Hardhat's public test account #0 as the university wallet; never use that key on a real network.
