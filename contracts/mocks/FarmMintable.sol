// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "../tokens/Farm.sol";

contract FarmMintable is Farm {
  function batchMint(address[] memory to, uint256[] memory amount) external onlyOwner {
    for (uint256 j = 0; j < to.length; j++) {
      for (uint256 i = 0; i < amount[j]; i++) {
        _safeMint(to[j], _nextTokenId++);
      }
    }
  }
}
