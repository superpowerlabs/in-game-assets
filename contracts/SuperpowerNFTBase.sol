// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// The staking part is taken from Everdragons2GenesisV2 contract
// https://github.com/ndujaLabs/everdragons2-core/blob/main/contracts/Everdragons2GenesisV2.sol

// Author: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@ndujalabs/wormhole721/contracts/Wormhole721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

import "./interfaces/IAttributable.sol";
import "./interfaces/IAttributablePlayer.sol";
import "./interfaces/ISuperpowerNFTBase.sol";

/*
About ownership and upgradeability

There is a strategy for it. Following OpenZeppelin best practices, we will deploy
the contracts and then transfer the ownership of the proxy-contract to a
Gnosis safe multi-sig wallet. Any subsequent upgrades will be performed
according to this process. Here is the guide we will follow to transfer ownership
to the multi-sig wallet and later deploy new implementations:
https://docs.openzeppelin.com/defender/guide-upgrades

To split the risks, a few more multi-sign wallets will become the owners of
the contracts in this suite.

Regarding the time lock, we are not implementing an explicit process because when
a bug is discovered (which is the primary reason why we are using upgradeable
contracts), the speed of response is crucial to avoid disaster.
For example, the recent crash of the UST could have been mitigated if they
did not have to wait for the fixed lockup time before intervening.

*/

abstract contract SuperpowerNFTBase is
  IAttributable,
  ISuperpowerNFTBase,
  Initializable,
  ERC721Upgradeable,
  ERC721EnumerableUpgradeable,
  Wormhole721Upgradeable
{
  using AddressUpgradeable for address;

  string private _baseTokenURI;
  bool private _baseTokenURIFrozen;

  mapping(address => bool) private _lockers;
  mapping(uint256 => address) private _lockedBy;
  address public game;

  mapping(uint256 => mapping(address => mapping(uint256 => uint256))) internal _tokenAttributes;

  modifier onlyLocker() {
    if (!_lockers[_msgSender()]) {
      revert NotALocker();
    }
    _;
  }

  modifier tokenExists(uint256 id) {
    if (!_exists(id)) {
      revert AssetDoesNotExist();
    }
    _;
  }

  // solhint-disable-next-line
  function __SuperpowerNFTBase_init(
    string memory name_,
    string memory symbol_,
    string memory tokenUri
  ) internal initializer {
    __Wormhole721_init(name_, symbol_);
    __ERC721Enumerable_init();
    __Ownable_init();
    _baseTokenURI = tokenUri;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
    if (from != address(0) && locked(tokenId)) {
      revert LockedAsset();
    }
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function preInitializeAttributesFor(uint256 _id, uint256 _attributes0) external override onlyOwner tokenExists(_id) {
    // we do not revert if already initialized because this is a
    // convenience function called by the owner to initialize the tokens
    if (_tokenAttributes[_id][game][0] == 0) {
      _tokenAttributes[_id][game][0] = _attributes0;
      emit AttributesInitializedFor(_id, game);
    }
  }

  // Attributable implementation

  function attributesOf(
    uint256 _id,
    address _player,
    uint256 _index
  ) external view override returns (uint256) {
    return _tokenAttributes[_id][_player][_index];
  }

  function initializeAttributesFor(uint256 _id, address _player) external virtual override {
    if (
      _msgSender() == ownerOf(_id) || // owner of the NFT
      (_msgSender() == game && _player == game) // the game itself
    ) {
      if (_msgSender() != game) {
        if (!_player.isContract()) revert NotAContract();
        if (IERC165Upgradeable(_player).supportsInterface(type(IAttributablePlayer).interfaceId))
          revert NotAnAttributablePlayer();
      }
      if (_tokenAttributes[_id][_player][0] > 0) {
        revert PlayerAlreadyAuthorized();
      }
      _tokenAttributes[_id][_player][0] = 1;
      emit AttributesInitializedFor(_id, _player);
    } else revert NotTheAssetOwnerNorTheGame();
  }

  function updateAttributes(
    uint256 _id,
    uint256 _index,
    uint256 _attributes
  ) external override {
    if (_tokenAttributes[_id][_msgSender()][0] == 0) {
      revert PlayerNotAuthorized();
    }
    // notice that if the playes set the attributes to zero, it de-authorize itself
    // and not more changes will be allowed until the NFT owner authorize it again
    _tokenAttributes[_id][_msgSender()][_index] = _attributes;
    emit AttributesUpdated(_id, _index, _attributes);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(Wormhole721Upgradeable, ERC721Upgradeable, ERC721EnumerableUpgradeable)
    returns (bool)
  {
    return
      interfaceId == type(IAttributable).interfaceId ||
      interfaceId == type(ILockable).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function updateTokenURI(string memory uri) external override onlyOwner {
    if (_baseTokenURIFrozen) {
      revert FrozenTokenURI();
    }
    // after revealing, this allows to set up a final uri
    _baseTokenURI = uri;
    emit TokenURIUpdated(uri);
  }

  function freezeTokenURI() external override onlyOwner {
    _baseTokenURIFrozen = true;
    emit TokenURIFrozen();
  }

  function contractURI() public view override returns (string memory) {
    return string(abi.encodePacked(_baseTokenURI, "0"));
  }

  function setGame(address game_) external virtual onlyOwner {
    if (game != address(0)) revert ZeroAddress();
    if (!game_.isContract()) revert NotAContract();
    game = game_;
    emit GameSet(game_);
  }

  // ILockable
  //
  // When a contract is locked, only the locker is approved
  // The advantage of locking an NFT instead of staking is that
  // The owner keeps the ownership of it and can use that, for example,
  // to access services on Discord via Collab.land verification.

  function locked(uint256 tokenId) public view override returns (bool) {
    if (!_exists(tokenId)) revert AssetDoesNotExist();
    return _lockedBy[tokenId] != address(0);
  }

  function lockerOf(uint256 tokenId) external view override returns (address) {
    return _lockedBy[tokenId];
  }

  function isLocker(address locker) public view override returns (bool) {
    return _lockers[locker];
  }

  function setLocker(address locker) external override onlyOwner {
    if (!locker.isContract()) {
      revert NotAContract();
    }
    _lockers[locker] = true;
    emit LockerSet(locker);
  }

  function removeLocker(address locker) external override onlyOwner {
    if (!_lockers[locker]) {
      revert NotALocker();
    }
    delete _lockers[locker];
    emit LockerRemoved(locker);
  }

  function hasLocks(address owner_) public view override returns (bool) {
    uint256 balance = balanceOf(owner_);
    for (uint256 i = 0; i < balance; i++) {
      uint256 id = tokenOfOwnerByIndex(owner_, i);
      if (locked(id)) {
        return true;
      }
    }
    return false;
  }

  function lock(uint256 tokenId) external override onlyLocker {
    if (getApproved(tokenId) != _msgSender() && !isApprovedForAll(ownerOf(tokenId), _msgSender())) {
      revert LockerNotApproved();
    }
    _lockedBy[tokenId] = _msgSender();
    emit Locked(tokenId, true);
  }

  function unlock(uint256 tokenId) external override onlyLocker {
    // will revert if token does not exist
    if (_lockedBy[tokenId] != _msgSender()) {
      revert WrongLocker();
    }
    delete _lockedBy[tokenId];
    emit Locked(tokenId, false);
  }

  // emergency function in case a compromised locker is removed
  function unlockIfRemovedLocker(uint256 tokenId) external override {
    if (!locked(tokenId)) {
      revert NotLockedAsset();
    }
    if (_lockers[_lockedBy[tokenId]]) {
      revert NotADeactivatedLocker();
    }
    if (ownerOf(tokenId) != _msgSender()) {
      revert NotTheAssetOwner();
    }
    delete _lockedBy[tokenId];
    emit ForcefullyUnlocked(tokenId);
  }

  // To obtain the lockability, the standard approval and transfer
  // functions of an ERC721 must be overridden, taking in consideration
  // the locking status of the NFT.

  // The _beforeTokenTransfer hook is enough to guarantee that a locked
  // NFT cannot be transferred. Overriding the approval functions, following
  // OpenZeppelin best practices, avoid the user to spend useless gas.

  function approve(address to, uint256 tokenId) public override(IERC721Upgradeable, ERC721Upgradeable) {
    if (locked(tokenId)) {
      revert LockedAsset();
    }
    super.approve(to, tokenId);
  }

  function getApproved(uint256 tokenId) public view override(IERC721Upgradeable, ERC721Upgradeable) returns (address) {
    if (locked(tokenId)) {
      return address(0);
    }
    return super.getApproved(tokenId);
  }

  function setApprovalForAll(address operator, bool approved) public override(IERC721Upgradeable, ERC721Upgradeable) {
    if (approved && hasLocks(_msgSender())) {
      revert AtLeastOneLockedAsset();
    }
    super.setApprovalForAll(operator, approved);
  }

  function isApprovedForAll(address owner_, address operator)
    public
    view
    override(IERC721Upgradeable, ERC721Upgradeable)
    returns (bool)
  {
    if (hasLocks(owner_)) {
      return false;
    }
    return super.isApprovedForAll(owner_, operator);
  }

  function wormholeTransfer(
    uint256 tokenID,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) public payable override whenNotPaused returns (uint64 sequence) {
    if (locked(tokenID)) revert LockedAsset();
    return super.wormholeTransfer(tokenID, recipientChain, recipient, nonce);
  }

  function pause(bool status) external onlyOwner {
    if (status) {
      _pause();
    } else {
      _unpause();
    }
  }

  uint256[49] private __gap;
}
