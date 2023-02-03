// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "../SuperpowerNFT.sol";

contract Turf is SuperpowerNFT {
  function initialize(string memory tokenUri) public initializer onlyProxy {
    __SuperpowerNFTBase_init("MOBLAND Turf", "mTURF", tokenUri);
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}
