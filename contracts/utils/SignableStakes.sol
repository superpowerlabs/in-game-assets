// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Authors: Francesco Sullo <francesco@sullo.co>

import "./Signable.sol";

contract SignableStakes is Signable {
  // these functions are called internally, and externally by the app
  function hashUnstake(
    uint8 tokenType,
    uint16 tokenId,
    uint16 indexOrId,
    uint256 randomNonce
  ) public view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x01", // EIP-191
          block.chainid,
          tokenType,
          tokenId,
          indexOrId,
          randomNonce
        )
      );
  }
}
