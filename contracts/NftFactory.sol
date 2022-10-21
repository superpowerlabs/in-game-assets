// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author : Francesco Sullo < francesco@superpower.io>
// (c) Superpower Labs Inc.

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "soliutils/contracts/UUPSUpgradableTemplate.sol";

import "./interfaces/ISuperpowerNFT.sol";
import "./EXTERNAL/synr-seed/token/SeedToken.sol";

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

  mapping(uint8 => ISuperpowerNFT) private _nfts;
  mapping(address => uint8) private _nftsByAddress;
  uint8 private _lastNft;
  mapping(uint8 => address) private _factories;
  mapping(uint8 => uint256) private _prices;
  mapping(uint8 => uint256) private _pricesInSeed;

  uint256 public proceedsBalance;
  uint256 public seedProceedsBalance;
  SeedToken public seedToken;

  modifier onlyFactory(uint8 nftId) {
    require(nftIdByFactory(_msgSender()) == nftId, "NftFactory: not a factory for this nft");
    _;
  }

  function initialize(address seed) public initializer {
    __UUPSUpgradableTemplate_init();
    require(seed.isContract(), "NftFactory: seed is not a contract");
    seedToken = SeedToken(seed);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function setNewNft(address nft) external onlyOwner {
    require(nft.isContract(), "NftFactory: not a contract");
    require(_nftsByAddress[nft] == 0, "NftFactory: token already set");
    _lastNft++;
    _nftsByAddress[nft] = _lastNft;
    _nfts[_lastNft] = ISuperpowerNFT(nft);
    emit NewNftForSale(_lastNft, nft);
  }

  function removeNewNft(address nft) external onlyOwner {
    require(_nftsByAddress[nft] > 0, "NftFactory: token not found");
    uint8 nftId = _nftsByAddress[nft];
    delete _nfts[nftId];
    delete _nftsByAddress[nft];
    emit NftRemovedFromSale(nftId, nft);
  }

  function setFactory(uint8 nftId, address factory) external onlyOwner {
    require(factory.isContract(), "NftFactory: not a contract");
    _factories[nftId] == factory;
    emit FactorySetFor(nftId, factory);
  }

  function removeFactoryForNft(uint8 nftId, address factory) external onlyOwner {
    require(_factories[nftId] == factory, "NftFactory: factory not found");
    delete _factories[nftId];
    emit FactoryRemovedFor(nftId, factory);
  }

  function setPrice(uint8 nftId, uint256 price) external onlyOwner {
    require(address(_nfts[nftId]) != address(0), "NftFactory: token not found");
    _prices[nftId] = price;
    emit NewPriceFor(nftId, price);
  }

  function getPrice(uint8 nftId) external view returns (uint256) {
    return _prices[nftId];
  }

  function setPriceInSeed(uint8 nftId, uint256 price) external onlyOwner {
    require(address(_nfts[nftId]) != address(0), "NftFactory: token not found");
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
    require(msg.value >= _prices[nftId].mul(amount), "NftFactory: insufficient payment");
    proceedsBalance += msg.value;
    _nfts[nftId].mint(_msgSender(), amount);
  }

  function withdrawProceeds(address beneficiary, uint256 amount) public onlyOwner {
    if (amount == 0) {
      amount = proceedsBalance;
    }
    require(amount <= proceedsBalance, "NftFactory: insufficient funds");
    proceedsBalance -= amount;
    (bool success, ) = beneficiary.call{value: amount}("");
    require(success);
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
    require(amount <= seedProceedsBalance, "NftFactory: insufficient SEEDS funds");
    seedProceedsBalance -= amount;
    seedToken.transferFrom(address(this), beneficiary, amount);
  }
}
