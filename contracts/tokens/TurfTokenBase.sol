// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "../interfaces/ITurfToken.sol";
import "../SuperpowerNFTBase.sol";

//import "hardhat/console.sol";

contract TurfTokenBase is ITurfToken, SuperpowerNFTBase {
  // when bridging the attributes must be propagated
  mapping(uint256 => TurfAttributes) internal _attributes;

  function attributes(uint256 tokenId) external view returns (TurfAttributes memory) {
    return _attributes[tokenId];
  }

  function attributesOf(uint256 tokenId) external view tokenExists(tokenId) returns (string memory) {
    return string(abi.encodePacked("uint8 level:", StringsUpgradeable.toString(_attributes[tokenId].level)));
  }

  function initAttributes(uint256 tokenId, TurfAttributes calldata attributes_) external onlyOwner tokenExists(tokenId) {
    _attributes[tokenId] = attributes_;
  }

  function updateAttributes(uint256 tokenId, TurfAttributes calldata attributes_) external onlyGame tokenExists(tokenId) {
    _attributes[tokenId] = attributes_;
  }
}
