// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "../interfaces/IFarmToken.sol";
import "../SuperpowerNFT.sol";

//import "hardhat/console.sol";

contract FarmToken is IFarmToken, SuperpowerNFT {
  // when bridging the attributes must be propagated
  // except if we prefer to reset the token on a new chain
  mapping(uint256 => FarmAttributes) public attributes;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(string memory tokenUri) public initializer {
    __SuperpowerNFTBase_init("MOBLAND Farm", "mFARM", tokenUri);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function attributesOf(uint256 tokenId) external view override tokenExists(tokenId) returns (string memory) {
    return
      string(
        abi.encodePacked(
          "uint8 level:",
          StringsUpgradeable.toString(attributes[tokenId].level),
          ";uint8 farmState:",
          StringsUpgradeable.toString(attributes[tokenId].farmState),
          ";uint32 currentHP:",
          StringsUpgradeable.toString(attributes[tokenId].currentHP),
          ";uint32 weedReserves:",
          StringsUpgradeable.toString(attributes[tokenId].weedReserves)
        )
      );
  }

  function updateAttributes(uint256 tokenId, FarmAttributes calldata attributes_) external onlyGame tokenExists(tokenId) {
    attributes[tokenId] = attributes_;
  }

  function updateLevel(uint256 tokenId, uint8 level) external onlyGame tokenExists(tokenId) {
    attributes[tokenId].level = level;
  }

  function updateCurrentHP(uint256 tokenId, uint32 currentHP) external onlyGame tokenExists(tokenId) {
    attributes[tokenId].currentHP = currentHP;
  }

  function updateFarmState(uint256 tokenId, uint8 farmState) external onlyGame tokenExists(tokenId) {
    attributes[tokenId].farmState = farmState;
  }

  function updateWeedReserves(uint256 tokenId, uint32 weedReserves) external onlyGame tokenExists(tokenId) {
    attributes[tokenId].weedReserves = weedReserves;
  }
}
