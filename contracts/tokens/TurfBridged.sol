// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "../SuperpowerNFTBase.sol";

contract TurfBridged is SuperpowerNFTBase {
  function initialize(string memory tokenUri) public initializer {
    __SuperpowerNFTBase_init("MOBLAND Turf", "mTURF", tokenUri);
  }
}
