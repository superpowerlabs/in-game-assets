// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// The staking part is taken from Everdragons2GenesisV2 contract
// https://github.com/ndujaLabs/everdragons2-core/blob/main/contracts/Everdragons2GenesisV2.sol

// Author: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@ndujalabs/wormhole721/contracts/Wormhole721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "./interfaces/ISuperpowerNFTBase.sol";

//import "hardhat/console.sol";

abstract contract SuperpowerNFTBase is
  ISuperpowerNFTBase,
  Initializable,
  ERC721Upgradeable,
  ERC721EnumerableUpgradeable,
  Wormhole721Upgradeable
{
  using AddressUpgradeable for address;

  event Locked(uint256 tokendId);
  event Unlocked(uint256 tokendId);

  string private _baseTokenURI;
  bool private _baseTokenURIFrozen;

  mapping(address => bool) public lockers;
  mapping(uint256 => address) public locked;
  address public game;

  modifier onlyLocker() {
    require(lockers[_msgSender()], "SuperpowerNFTBase: not a staking locker");
    _;
  }

  modifier onlyGame() {
    require(game != address(0) && _msgSender() == game, "SuperpowerNFTBase: not the game");
    _;
  }

  // solhint-disable-next-line
  function __SuperpowerNFTBase_init(
    string memory name,
    string memory symbol,
    string memory tokenUri
  ) internal initializer {
    __Wormhole721_init(name, symbol);
    __ERC721Enumerable_init();
    _baseTokenURI = tokenUri;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
    require(!isLocked(tokenId), "SuperpowerNFTBase: locked asset");
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(Wormhole721Upgradeable, ERC721Upgradeable, ERC721EnumerableUpgradeable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function updateTokenURI(string memory uri) external override onlyOwner {
    require(!_baseTokenURIFrozen, "SuperpowerNFTBase: baseTokenUri has been frozen");
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

  function setGame(address game_) external onlyOwner {
    require(game_.isContract(), "SuperpowerNFTBase: game_ not a contract");
    game = game_;
    emit GameSet(game_);
  }

  // locks

  function isLocked(uint256 tokenId) public view override returns (bool) {
    return locked[tokenId] != address(0);
  }

  function getLocker(uint256 tokenId) external view override returns (address) {
    return locked[tokenId];
  }

  function setLocker(address locker) external override onlyOwner {
    require(locker.isContract(), "SuperpowerNFTBase: locker not a contract");
    lockers[locker] = true;
    emit LockerSet(locker);
  }

  function removeLocker(address locker) external override onlyOwner {
    require(lockers[locker], "SuperpowerNFTBase: not an active locker");
    delete lockers[locker];
    emit LockerRemoved(locker);
  }

  function hasLocks(address owner) public view override returns (bool) {
    uint256 balance = balanceOf(owner);
    for (uint256 i = 0; i < balance; i++) {
      uint256 id = tokenOfOwnerByIndex(owner, i);
      if (isLocked(id)) {
        return true;
      }
    }
    return false;
  }

  function lock(uint256 tokenId) external override onlyLocker {
    // locker must be approved to mark the token as locked
    require(getApproved(tokenId) == _msgSender() || isApprovedForAll(ownerOf(tokenId), _msgSender()), "Locker not approved");
    locked[tokenId] = _msgSender();
    emit Locked(tokenId);
  }

  function unlock(uint256 tokenId) external override onlyLocker {
    // will revert if token does not exist
    require(locked[tokenId] == _msgSender(), "SuperpowerNFTBase: wrong locker");
    delete locked[tokenId];
    emit Unlocked(tokenId);
  }

  // emergency function in case a compromised locker is removed
  function unlockIfRemovedLocker(uint256 tokenId) external override onlyOwner {
    require(isLocked(tokenId), "SuperpowerNFTBase: not a locked tokenId");
    require(!lockers[locked[tokenId]], "SuperpowerNFTBase: locker is still active");
    delete locked[tokenId];
    emit LockRemoved(tokenId);
  }

  // manage approval

  function approve(address to, uint256 tokenId) public override {
    require(!isLocked(tokenId), "SuperpowerNFTBase: locked asset");
    super.approve(to, tokenId);
  }

  function getApproved(uint256 tokenId) public view override returns (address) {
    if (isLocked(tokenId)) {
      return address(0);
    }
    return super.getApproved(tokenId);
  }

  function setApprovalForAll(address operator, bool approved) public override {
    require(!approved || !hasLocks(_msgSender()), "SuperpowerNFTBase: at least one asset is locked");
    super.setApprovalForAll(operator, approved);
  }

  function isApprovedForAll(address owner, address operator) public view override returns (bool) {
    if (hasLocks(owner)) {
      return false;
    }
    return super.isApprovedForAll(owner, operator);
  }

  uint256[50] private __gap;
}
