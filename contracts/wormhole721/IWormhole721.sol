// SPDX-License-Identifier: Apache2
pragma solidity ^0.8.0;

interface IWormhole721 {
  function wormholeTransfer(
    uint256 tokenID,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) external payable returns (uint64 sequence);

  function wormholeCompleteTransfer(bytes memory encodedVm) external;
}
