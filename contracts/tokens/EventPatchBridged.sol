// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "../SuperpowerNFTBase.sol";

// Intermediate contract to fix a typo in the Locked and Unlocked events

contract EventPatchBridged is SuperpowerNFTBase {
  // Unfortunately, there was a typo in the parameter tokenId of the events
  // Locked and Unlocked, where it was spelled "tokendId".
  // This patch fixes the typo and emits new events with the correct parameter name.

  bool public defaultLockedEmitted;

  function emitDefaultLockedEvent() public onlyOwner {
    if (!defaultLockedEmitted) {
      emit DefaultLocked(true);
      defaultLockedEmitted = true;
    }
  }

  uint256[50] private __gap;
}
