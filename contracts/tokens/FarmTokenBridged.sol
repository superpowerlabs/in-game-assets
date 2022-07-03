// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "./IFarm.sol";
import "../SuperpowerNFTBase.sol";

//import "hardhat/console.sol";

contract FarmTokenBridged is IFarm, SuperpowerNFTBase {
  // when bridging the attributes must be propagated
  // except if we prefer to reset the token on a new chain
  mapping(uint256 => Attributes) public attributes;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(string memory tokenUri) public initializer {
    __SuperpowerNFTBase_init("MOBLAND Farm", "mFARM", tokenUri);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function attributesOf(uint tokenId) external view returns (string memory) {
    return string(abi.encodePacked(
        "uint8 level:",
        StringsUpgradeable.toString(attributes[tokenId].level),
        ";uint8 farmState:",
        StringsUpgradeable.toString(attributes[tokenId].farmState),
        ";uint32 currentHP:",
        StringsUpgradeable.toString(attributes[tokenId].currentHP),
        ";uint32 weedReserves:",
        StringsUpgradeable.toString(attributes[tokenId].weedReserves)
      ));
  }

  function updateAttributes(uint256 tokenId, Attributes calldata attributes_) external onlyGame {
    attributes[tokenId] = attributes_;
  }

  function updateLevel(uint256 tokenId, uint8 level) external onlyGame {
    attributes[tokenId].level = level;
  }

  function updateCurrentHP(uint256 tokenId, uint32 currentHP) external onlyGame {
    attributes[tokenId].currentHP = currentHP;
  }

  function updateFarmState(uint256 tokenId, uint8 farmState) external onlyGame {
    attributes[tokenId].farmState = farmState;
  }

  function updateWeedReserves(uint256 tokenId, uint32 weedReserves) external onlyGame {
    attributes[tokenId].weedReserves = weedReserves;
  }
}
