// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract DocRegistry {
    struct Doc { bytes32 hash; address issuer; uint64 issuedAt; bool revoked; }

    address public owner = msg.sender; // the university
    mapping(bytes32 => Doc) public docs;      // certId => Doc
    mapping(bytes32 => bytes32) public idOf;  // hash => certId

    event Issued(bytes32 indexed id, bytes32 hash, address issuer);
    event Revoked(bytes32 indexed id);

    modifier onlyOwner() { require(msg.sender == owner, "not university"); _; }

    function issue(bytes32 id, bytes32 hash) external onlyOwner {
        require(docs[id].issuedAt == 0, "id exists");
        require(idOf[hash] == 0, "hash exists");
        docs[id] = Doc(hash, msg.sender, uint64(block.timestamp), false);
        idOf[hash] = id;
        emit Issued(id, hash, msg.sender);
    }

    function revoke(bytes32 id) external onlyOwner {
        require(docs[id].issuedAt != 0, "unknown id");
        docs[id].revoked = true;
        emit Revoked(id);
    }

    // exists=false => altered / unregistered
    function verify(bytes32 hash) external view returns (bool exists, bytes32 id, Doc memory d) {
        id = idOf[hash];
        exists = id != 0;
        d = docs[id];
    }
}
