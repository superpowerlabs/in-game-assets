// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

// In the first version of the contracts, there was a typo
// To be able to read those events, we need them in the ABI and this is
// why we need this interface

interface IOldBrokenLockable {
  event Locked(uint256 tokendId);
  event Unlocked(uint256 tokendId);
}
