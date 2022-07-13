// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author: Francesco Sullo <francesco@superpower.io>

interface ICharacterToken {
  // this is just an example
  struct CharacterAttributes {
    uint8 level;
    uint8 state;
    uint32 currentHP;
  }
}
