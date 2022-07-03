// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "./ITurf.sol";
import "../SuperpowerNFTBase.sol";

//import "hardhat/console.sol";

contract TurfTokenBridged is ITurf, SuperpowerNFTBase {
  // when bridging the attributes must be propagated
  // except if we prefer to reset the token on a new chain
  mapping(uint256 => Attributes) public attributes;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(string memory tokenUri) public initializer {
    __SuperpowerNFTBase_init("MOBLAND Turf", "mTURF", tokenUri);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function attributesOf(uint tokenId) external view override tokenExists(tokenId) returns (string memory) {
    return string(abi.encodePacked(
        "uint8 level:",
        StringsUpgradeable.toString(attributes[tokenId].level)
      ));
  }

  function updateAttributes(uint256 tokenId, Attributes calldata attributes_) external onlyGame {
    attributes[tokenId] = attributes_;
  }
}
