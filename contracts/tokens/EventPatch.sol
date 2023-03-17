// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "../SuperpowerNFT.sol";

// Intermediate contract to fix a typo in the Locked and Unlocked events

contract EventPatch is SuperpowerNFT {
  // Unfortunately, there was a typo in the parameter "tokenId" of the events
  // Locked and Unlocked, and it was spelled as "tokendId".
  // This patch fixes the typo and emits new events with the correct parameter name.

  bool public defaultLockedEmitted;
  uint256 public lastCheckedId;

  function emitDefaultLockedEvent() public onlyOwner {
    if (!defaultLockedEmitted) {
      emit DefaultLocked(true);
      defaultLockedEmitted = true;
    }
  }

  function emitNewLockedEvent() public {
    uint256 fromId = lastCheckedId + 1;
    for (uint256 i = fromId; i < _nextTokenId; i++) {
      if (locked(i)) {
        emit Locked(i, true);
      }
      if (gasleft() < 40000) {
        lastCheckedId = i;
        return;
      }
    }
  }

  uint256[50] private __gap;
}
