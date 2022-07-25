// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "./TurfTokenBase.sol";
import "../SuperpowerNFT.sol";

//import "hardhat/console.sol";

contract TurfToken is TurfTokenBase, SuperpowerNFT {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(string memory tokenUri) public initializer {
    __SuperpowerNFTBase_init("MOBLAND Turf", "mTURF", tokenUri);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
