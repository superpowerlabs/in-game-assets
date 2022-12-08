// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

// the goal of this mock is to allow testing.
// We assume that the bridging is successful

import "../libraries/BytesLib.sol";

contract WormholeMock {
  using BytesLib for bytes;
  event LogMessagePublished(address indexed sender, uint64 sequence, uint32 nonce, bytes payload, uint8 consistencyLevel);

  struct Signature {
    bytes32 r;
    bytes32 s;
    uint8 v;
    uint8 guardianIndex;
  }

  struct VM {
    uint8 version;
    uint32 timestamp;
    uint32 nonce;
    uint16 emitterChainId;
    bytes32 emitterAddress;
    uint64 sequence;
    uint8 consistencyLevel;
    bytes payload;
    uint32 guardianSetIndex;
    Signature[] signatures;
    bytes32 hash;
  }

  mapping(address => uint64) private _sequences;

  // Publish a message to be attested by the Wormhole network
  function publishMessage(
    uint32 nonce,
    bytes memory payload,
    uint8 consistencyLevel
  ) public payable returns (uint64 sequence) {
    sequence = _sequences[msg.sender];
    _sequences[msg.sender] += 1;
    emit LogMessagePublished(msg.sender, sequence, nonce, payload, consistencyLevel);
  }
  //
  //  function parseAndVerifyVM(bytes calldata encodedVM)
  //    public
  //    view
  //    returns (
  //      VM memory vm,
  //      bool valid,
  //      string memory reason
  //    )
  //  {
  //    vm = parseVM(encodedVM);
  //    // TODO check it somehow
  //    // for now we assume it is valid
  //    //    (valid, reason) = verifyVM(vm);
  //    return (vm, true, "");
  //  }
  //
  //  function parseVM(bytes memory encodedVM) public pure virtual returns (VM memory vm) {
  //    uint256 index = 0;
  //
  //    vm.version = encodedVM.toUint8(index);
  //    index += 1;
  //    require(vm.version == 1, "VM version incompatible");
  //
  //    vm.guardianSetIndex = encodedVM.toUint32(index);
  //    index += 4;
  //
  //    // Parse Signatures
  //    uint256 signersLen = encodedVM.toUint8(index);
  //    index += 1;
  //    vm.signatures = new Signature[](signersLen);
  //    for (uint256 i = 0; i < signersLen; i++) {
  //      vm.signatures[i].guardianIndex = encodedVM.toUint8(index);
  //      index += 1;
  //
  //      vm.signatures[i].r = encodedVM.toBytes32(index);
  //      index += 32;
  //      vm.signatures[i].s = encodedVM.toBytes32(index);
  //      index += 32;
  //      vm.signatures[i].v = encodedVM.toUint8(index) + 27;
  //      index += 1;
  //    }
  //
  //    // Hash the body
  //    bytes memory body = encodedVM.slice(index, encodedVM.length - index);
  //    vm.hash = keccak256(abi.encodePacked(keccak256(body)));
  //
  //    // Parse the body
  //    vm.timestamp = encodedVM.toUint32(index);
  //    index += 4;
  //
  //    vm.nonce = encodedVM.toUint32(index);
  //    index += 4;
  //
  //    vm.emitterChainId = encodedVM.toUint16(index);
  //    index += 2;
  //
  //    vm.emitterAddress = encodedVM.toBytes32(index);
  //    index += 32;
  //
  //    vm.sequence = encodedVM.toUint64(index);
  //    index += 8;
  //
  //    vm.consistencyLevel = encodedVM.toUint8(index);
  //    index += 1;
  //
  //    vm.payload = encodedVM.slice(index, encodedVM.length - index);
  //  }
}
