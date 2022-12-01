// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "../SuperpowerNFT.sol";

//import "hardhat/console.sol";

contract Turf is SuperpowerNFT {
  function initialize(string memory tokenUri) public initializer {
    __SuperpowerNFTBase_init("MOBLAND Turf", "mTURF", tokenUri);
  }
}
