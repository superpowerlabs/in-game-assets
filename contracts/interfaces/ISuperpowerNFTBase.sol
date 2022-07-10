// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author: Francesco Sullo <francesco@superpower.io>

interface ISuperpowerNFTBase {
  event GameSet(address game);
  event TokenURIFrozen();
  event TokenURIUpdated(string uri);
  event LockerSet(address locker);
  event LockerRemoved(address locker);
  event LockRemoved(uint256 tokenId);

  function attributesOf(uint tokenId) external view returns (string memory);

  function updateTokenURI(string memory uri) external;

  function freezeTokenURI() external;

  function contractURI() external view returns (string memory);

  function isLocked(uint256 tokenID) external view returns (bool);

  function getLocker(uint256 tokenID) external view returns (address);

  function setLocker(address pool) external;

  function removeLocker(address pool) external;

  function hasLocks(address owner) external view returns (bool);

  function lock(uint256 tokenID) external;

  function unlock(uint256 tokenID) external;

  function unlockIfRemovedLocker(uint256 tokenID) external;
}
