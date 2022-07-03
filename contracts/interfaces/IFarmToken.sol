// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author: Francesco Sullo <francesco@superpower.io>

interface IFarmToken {
  struct FarmAttributes {
    uint8 level;
    uint8 farmState;
    uint32 currentHP;
    uint32 weedReserves;
  }
}
