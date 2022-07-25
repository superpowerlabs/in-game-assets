// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "../interfaces/IFarmToken.sol";
import "../SuperpowerNFTBase.sol";

//import "hardhat/console.sol";

contract FarmTokenBase is IFarmToken, SuperpowerNFTBase {
  // when bridging the attributes must be propagated
  mapping(uint256 => FarmAttributes) internal _attributes;

  function attributes(uint256 tokenId) external view returns (FarmAttributes memory) {
    return _attributes[tokenId];
  }

  function attributesOf(uint256 tokenId) external view tokenExists(tokenId) returns (string memory) {
    return
      string(
        abi.encodePacked(
          "uint8 level:",
          StringsUpgradeable.toString(_attributes[tokenId].level),
          ";uint8 farmState:",
          StringsUpgradeable.toString(_attributes[tokenId].farmState),
          ";uint32 currentHP:",
          StringsUpgradeable.toString(_attributes[tokenId].currentHP),
          ";uint32 weedReserves:",
          StringsUpgradeable.toString(_attributes[tokenId].weedReserves)
        )
      );
  }

  function initAttributes(uint256 tokenId, FarmAttributes calldata attributes_) external onlyOwner tokenExists(tokenId) {
    require(_attributes[tokenId].level == 0, "FarmTokenBase: attributes already set");
    _attributes[tokenId] = attributes_;
  }

  function updateAttributes(uint256 tokenId, FarmAttributes calldata attributes_) external onlyGame tokenExists(tokenId) {
    require(_attributes[tokenId].level != 0, "FarmTokenBase: attributes not set, yet");
    _attributes[tokenId] = attributes_;
  }

  function updateLevel(uint256 tokenId, uint8 level) external onlyGame tokenExists(tokenId) {
    require(_attributes[tokenId].level != 0, "FarmTokenBase: attributes not set, yet");
    _attributes[tokenId].level = level;
  }

  function updateCurrentHP(uint256 tokenId, uint32 currentHP) external onlyGame tokenExists(tokenId) {
    require(_attributes[tokenId].level != 0, "FarmTokenBase: attributes not set, yet");
    _attributes[tokenId].currentHP = currentHP;
  }

  function updateFarmState(uint256 tokenId, uint8 farmState) external onlyGame tokenExists(tokenId) {
    require(_attributes[tokenId].level != 0, "FarmTokenBase: attributes not set, yet");
    _attributes[tokenId].farmState = farmState;
  }

  function updateWeedReserves(uint256 tokenId, uint32 weedReserves) external onlyGame tokenExists(tokenId) {
    require(_attributes[tokenId].level != 0, "FarmTokenBase: attributes not set, yet");
    _attributes[tokenId].weedReserves = weedReserves;
  }
}
