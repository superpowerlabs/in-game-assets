// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author: Francesco Sullo <francesco@superpower.io>

import "@ndujalabs/lockable/contracts/ILockable.sol";

interface ISuperpowerNFTBase is ILockable {
  event GameSet(address game);
  event TokenURIFrozen();
  event TokenURIUpdated(string uri);

  function updateTokenURI(string memory uri) external;

  function freezeTokenURI() external;

  function contractURI() external view returns (string memory);
}
