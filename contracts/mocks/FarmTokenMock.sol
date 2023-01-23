// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "../tokens/Farm.sol";

contract FarmTokenMock is Farm {
  function setGame(address game_) external virtual override onlyOwner {
    game = game_;
    emit GameSet(game_);
  }

  function mint(address to, uint256 amount) external override {
    for (uint256 i = 0; i < amount; i++) {
      _safeMint(to, _nextTokenId++);
    }
  }

  function initializeAttributesFor(uint256 _id, address _player) external override {
    if (
      _msgSender() == ownerOf(_id) || // owner of the NFT
      (_msgSender() == game && _player == game) // the game itself
    ) {
      if (_tokenAttributes[_id][_player][0] > 0) {
        revert PlayerAlreadyAuthorized();
      }
      _tokenAttributes[_id][_player][0] = 1;
      emit AttributesInitializedFor(_id, _player);
    } else revert NotTheAssetOwnerNorTheGame();
  }
}
