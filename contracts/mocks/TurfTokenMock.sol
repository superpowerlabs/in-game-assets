// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "../tokens/Turf.sol";

contract TurfTokenMock is Turf {
  function setGame(address game_) external virtual override onlyOwner {
    game = game_;
    emit GameSet(game_);
  }

  function mint(address to, uint256 amount) external override {
    for (uint256 i = 0; i < amount; i++) {
      _safeMint(to, _nextTokenId++);
    }
  }
}
