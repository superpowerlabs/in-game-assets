// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author : Francesco Sullo < francesco@superpower.io>
// (c) Superpower Labs Inc.

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "soliutils/contracts/UUPSUpgradableTemplate.sol";

import "./interfaces/ISuperpowerNFT.sol";
import "../external-contracts/synr-seed/token/SeedToken.sol";

//import "hardhat/console.sol";

contract NftFactory is UUPSUpgradableTemplate {
  using AddressUpgradeable for address;
  using SafeMathUpgradeable for uint256;

  event NewPriceFor(uint8 nftId, uint256 price);
  event NewPriceInSeedFor(uint8 nftId, uint256 price);
  event FactorySetFor(uint8 nftId, address factory);
  event FactoryRemovedFor(uint8 nftId, address factory);
  event NewNftForSale(uint8 nftId, address nft);
  event NftRemovedFromSale(uint8 nftId, address nft);

  error NotAFactoryForThisNFT(uint id);
  error NotAContract();
  error NFTAlreadySet();
  error NFTNotFound();
  error FactoryNotFound();
  error InsufficientPayment();
  error InsufficientFunds();
  error TransferFailed();

  mapping(uint8 => ISuperpowerNFT) private _nfts;
  mapping(address => uint8) private _nftsByAddress;
  uint8 private _lastNft;
  mapping(uint8 => address) private _factories;
  mapping(uint8 => uint256) private _prices;
  mapping(uint8 => uint256) private _pricesInSeed;

  uint256 public proceedsBalance;
  uint256 public seedProceedsBalance;
  ERC20 public seedToken;
  ERC20 public usdToken;

  modifier onlyFactory(uint8 nftId) {
    if (nftIdByFactory(_msgSender()) != nftId) revert NotAFactoryForThisNFT(nftId);
    _;
  }

  function initialize(address seed, address stableCoin) public initializer {
    __UUPSUpgradableTemplate_init();
    if (!seed.isContract()) revert NotAContract();
    else if (!stableCoin.isContract()) revert NotAContract();
    seedToken = ERC20(seed);
    usdToken = ERC20(stableCoin);
  }

  function setNewNft(address nft) external onlyOwner {
    if (!nft.isContract()) revert NotAContract();
    if (_nftsByAddress[nft] > 0) revert NFTAlreadySet();
    _lastNft++;
    _nftsByAddress[nft] = _lastNft;
    _nfts[_lastNft] = ISuperpowerNFT(nft);
    emit NewNftForSale(_lastNft, nft);
  }

  function removeNewNft(address nft) external onlyOwner {
    if (_nftsByAddress[nft] == 0) revert NFTNotFound();
    uint8 nftId = _nftsByAddress[nft];
    delete _nfts[nftId];
    delete _nftsByAddress[nft];
    emit NftRemovedFromSale(nftId, nft);
  }

  function setFactory(uint8 nftId, address factory) external onlyOwner {
    if (!factory.isContract()) revert NotAContract();
    _factories[nftId] == factory;
    emit FactorySetFor(nftId, factory);
  }

  function removeFactoryForNft(uint8 nftId, address factory) external onlyOwner {
    if (_factories[nftId] != factory) revert FactoryNotFound();
    delete _factories[nftId];
    emit FactoryRemovedFor(nftId, factory);
  }

  function setPrice(uint8 nftId, uint256 price) external onlyOwner {
    if (address(_nfts[nftId]) == address(0)) revert NFTNotFound();
    _prices[nftId] = price;
    emit NewPriceFor(nftId, price);
  }

  function getPrice(uint8 nftId) external view returns (uint256) {
    return _prices[nftId];
  }

  function setPriceInSeed(uint8 nftId, uint256 price) external onlyOwner {
    if (address(_nfts[nftId]) == address(0)) revert NFTNotFound();
    _pricesInSeed[nftId] = price;
    emit NewPriceInSeedFor(nftId, price);
  }

  function getPriceInSeed(uint8 nftId) external view returns (uint256) {
    return _pricesInSeed[nftId];
  }

  function nftIdByFactory(address factory) public view returns (uint8) {
    for (uint8 i = 0; i < _lastNft + 1; i++) {
      if (_factories[i] == factory) {
        return i;
      }
    }
    return 0;
  }

  function buyTokens(uint8 nftId, uint256 amount) external payable {
    if (msg.value < _prices[nftId].mul(amount)) revert InsufficientPayment();
    proceedsBalance += msg.value;
    _nfts[nftId].mint(_msgSender(), amount);
  }

  function withdrawProceeds(address beneficiary, uint256 amount) public onlyOwner {
    if (amount == 0) {
      amount = proceedsBalance;
    }
    if (amount > proceedsBalance) revert InsufficientFunds();
    proceedsBalance -= amount;
    // solhint-disable-next-line avoid-low-level-calls
    (bool success, ) = beneficiary.call{value: amount}("");
    if (!success) {
      revert TransferFailed();
    }
  }

  function buyTokensWithSeeds(uint8 nftId, uint256 amount) external payable {
    uint256 seedAmount = _pricesInSeed[nftId].mul(amount);
    seedProceedsBalance += seedAmount;
    seedToken.transferFrom(_msgSender(), address(this), seedAmount);
    _nfts[nftId].mint(_msgSender(), amount);
  }

  function withdrawSeedProceeds(address beneficiary, uint256 amount) public onlyOwner {
    if (amount == 0) {
      amount = seedProceedsBalance;
    }
    if (amount > seedProceedsBalance) revert InsufficientFunds();
    seedProceedsBalance -= amount;
    seedToken.transferFrom(address(this), beneficiary, amount);
  }
}
