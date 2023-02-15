// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Author: Francesco Sullo <francesco@superpower.io>

import "./ILockable.sol";

interface ISuperpowerNFTBase is ILockable {
  event GameSet(address game);
  event TokenURIFrozen();
  event TokenURIUpdated(string uri);
  event AttributesUpdated(uint256 _id, uint256 _index, uint256 _attributes);

  error NotALocker();
  error NotTheGame();
  error NotTheAssetOwnerNorTheGame();
  error AssetDoesNotExist();
  error PlayerAlreadyAuthorized();
  error PlayerNotAuthorized();
  error FrozenTokenURI();
  error NotAContract();
  error NotADeactivatedLocker();
  error WrongLocker();
  error NotLockedAsset();
  error LockedAsset();
  error AtLeastOneLockedAsset();
  error LockerNotApproved();
  error ZeroAddress();
  error NotAnAttributablePlayer();
  error NotTheAssetOwner();

  function updateTokenURI(string memory uri) external;

  function freezeTokenURI() external;

  function contractURI() external view returns (string memory);

  function preInitializeAttributesFor(uint256 _id, uint256 _attributes0) external;
}
