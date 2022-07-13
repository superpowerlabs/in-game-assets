// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "./FarmTokenBase.sol";
import "../SuperpowerNFT.sol";

//import "hardhat/console.sol";

contract FarmToken is FarmTokenBase, SuperpowerNFT {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(string memory tokenUri) public initializer {
    __SuperpowerNFTBase_init("MOBLAND Farm", "mFARM", tokenUri);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
