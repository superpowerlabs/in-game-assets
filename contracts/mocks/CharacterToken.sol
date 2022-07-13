// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "./ICharacterToken.sol";
import "../SuperpowerNFT.sol";

//import "hardhat/console.sol";

contract CharacterToken is ICharacterToken, SuperpowerNFT {
  // when bridging the attributes must be propagated
  // except if we prefer to reset the token on a new chain
  mapping(uint256 => CharacterAttributes) public attributes;
  uint256 nextTokenId;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(string memory tokenUri) public initializer {
    __SuperpowerNFTBase_init("MOBLAND Character", "mCHAR", tokenUri);
    nextTokenId = 1;
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function attributesOf(uint256 tokenId) external view override tokenExists(tokenId) returns (string memory) {
    return
      string(
        abi.encodePacked(
          "uint8 level:",
          StringsUpgradeable.toString(attributes[tokenId].level),
          ";uint8 state:",
          StringsUpgradeable.toString(attributes[tokenId].state),
          ";uint32 currentHP:",
          StringsUpgradeable.toString(attributes[tokenId].currentHP)
        )
      );
  }

  function initAttributes(uint256 tokenId, CharacterAttributes calldata attributes_) external onlyOwner tokenExists(tokenId) {
    attributes[tokenId] = attributes_;
  }

  function updateAttributes(uint256 tokenId, CharacterAttributes calldata attributes_) external onlyGame tokenExists(tokenId) {
    attributes[tokenId] = attributes_;
  }

  function updateLevel(uint256 tokenId, uint8 level) external onlyGame tokenExists(tokenId) {
    attributes[tokenId].level = level;
  }

  function updateState(uint256 tokenId, uint8 state) external onlyGame tokenExists(tokenId) {
    attributes[tokenId].state = state;
  }

  function updateCurrentHP(uint256 tokenId, uint32 currentHP) external onlyGame tokenExists(tokenId) {
    attributes[tokenId].currentHP = currentHP;
  }

  function mint(address to, uint256 amount) external override onlyOwner {
    for (uint256 i = 0; i < amount; i++) {
      _safeMint(to, _nextTokenId++);
    }
  }
}
