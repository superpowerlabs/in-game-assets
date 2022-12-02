// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Inspired by Everdragons2 NFTs, https://everdragons2.com
// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "./SuperpowerNFTBase.sol";
import "./interfaces/ISuperpowerNFT.sol";
import "./WhitelistSlot.sol";

//import "hardhat/console.sol";

abstract contract SuperpowerNFT is ISuperpowerNFT, SuperpowerNFTBase {
  error Forbidden();
  error CannotMint();
  error ZeroAddress();
  error InvalidSupply();
  error NotEnoughWLSlots();
  error InvalidDeadline();

  using AddressUpgradeable for address;
  uint256 internal _nextTokenId;
  uint256 internal _maxSupply;
  bool internal _mintEnded;

  mapping(address => bool) public factories;

  uint256 private _whitelistActiveUntil;
  WhitelistSlot private _wl;
  address public defaultPlayer;

  modifier onlyFactory() {
    if (_msgSender() == address(0) || !factories[_msgSender()]) revert Forbidden();
    _;
  }

  modifier canMint(uint256 amount) {
    if (!canMintAmount(amount)) revert CannotMint();
    _;
  }

  function setDefaultPlayer(address player) external onlyOwner {
    if (!player.isContract()) revert NotAContract();
    defaultPlayer = player;
  }

  function setWhitelist(address wl, uint256 activeUntil) external onlyOwner {
    if (wl == address(0)) revert ZeroAddress();
    if (!wl.isContract()) revert NotAContract();
    _wl = WhitelistSlot(wl);
    // solhint-disable-next-line not-rely-on-time
    if (activeUntil < block.timestamp) revert InvalidDeadline();
    _whitelistActiveUntil = activeUntil;
  }

  function setMaxSupply(uint256 maxSupply_) external onlyOwner {
    if (_nextTokenId == 0) {
      _nextTokenId = 1;
    }
    if (_nextTokenId > maxSupply_) revert InvalidSupply();
    _maxSupply = maxSupply_;
  }

  function setFactory(address factory_, bool enabled) external override onlyOwner {
    if (!factory_.isContract()) revert NotAContract();
    factories[factory_] = enabled;
  }

  function canMintAmount(uint256 amount) public view returns (bool) {
    return _nextTokenId > 0 && !_mintEnded && _nextTokenId + amount < _maxSupply + 2;
  }

  function mint(address to, uint256 amount) external virtual override onlyFactory canMint(amount) {
    for (uint256 i = 0; i < amount; i++) {
      _safeMint(to, _nextTokenId++);
    }
    _burnWhitelistSlot(to, amount);
  }

  function _burnWhitelistSlot(address to, uint256 amount) internal {
    // solhint-disable-next-line not-rely-on-time
    if (block.timestamp < _whitelistActiveUntil) {
      if (_wl.balanceOf(to, _wl.getIdByBurner(address(this))) < amount) revert NotEnoughWLSlots();
      _wl.burn(to, _wl.getIdByBurner(address(this)), amount);
    }
  }

  function endMinting() external override onlyOwner {
    _mintEnded = true;
  }

  function mintEnded() external view override returns (bool) {
    return _mintEnded;
  }

  function maxSupply() external view override returns (uint256) {
    return _maxSupply;
  }

  function nextTokenId() external view override returns (uint256) {
    return _nextTokenId;
  }
}
