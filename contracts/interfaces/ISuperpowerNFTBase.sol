// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Author: Francesco Sullo <francesco@superpower.io>

import "./ILockable.sol";

interface ISuperpowerNFTBase is ILockable {
  event GameSet(address game);
  event TokenURIFrozen();
  event TokenURIUpdated(string uri);

  function updateTokenURI(string memory uri) external;

  function freezeTokenURI() external;

  function contractURI() external view returns (string memory);

  function preInitializeAttributesFor(uint256 _id, uint256 _attributes0) external;
}
