// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "../interfaces/ITurfToken.sol";
import "../SuperpowerNFT.sol";

//import "hardhat/console.sol";

contract TurfToken is ITurfToken, SuperpowerNFT {
  // when bridging the attributes must be propagated
  // except if we prefer to reset the token on a new chain
  mapping(uint256 => TurfAttributes) public attributes;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(string memory tokenUri) public initializer {
    __SuperpowerNFTBase_init("MOBLAND Turf", "mTURF", tokenUri);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function attributesOf(uint256 tokenId) external view override tokenExists(tokenId) returns (string memory) {
    return string(abi.encodePacked("uint8 level:", StringsUpgradeable.toString(attributes[tokenId].level)));
  }

  function initAttributes(uint256 tokenId, TurfAttributes calldata attributes_) external onlyOwner tokenExists(tokenId) {
    attributes[tokenId] = attributes_;
  }

  function updateAttributes(uint256 tokenId, TurfAttributes calldata attributes_) external onlyGame tokenExists(tokenId) {
    attributes[tokenId] = attributes_;
  }
}
