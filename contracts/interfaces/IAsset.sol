// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Author: Francesco Sullo <francesco@superpower.io>

import "./ILockable.sol";
import "./IAttributable.sol";

interface IAsset is ILockable, IAttributable {
  struct FarmAttributes {
    uint8 level;
    uint8 farmState;
    uint32 currentHP;
    uint32 weedReserves;
  }

  struct TurfAttributes {
    uint8 level;
  }
}
