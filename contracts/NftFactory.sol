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

  event NewPriceFor(uint8 nftId, address paymentToken, uint256 price);
  event NewPriceInSeedFor(uint8 nftId, uint256 price);
  event FactorySetFor(uint8 nftId, address factory);
  event FactoryRemovedFor(uint8 nftId, address factory);
  event NewNftForSale(uint8 nftId, address nft);
  event NftRemovedFromSale(uint8 nftId, address nft);

  error NotAFactoryForThisNFT(uint256 id);
  error NotAContract();
  error NFTAlreadySet();
  error NFTNotFound();
  error FactoryNotFound();
  error InsufficientPayment();
  error InsufficientFunds();
  error TransferFailed();
  error InvalidPaymentToken();

  mapping(uint8 => ISuperpowerNFT) private _nfts;
  mapping(address => uint8) private _nftsByAddress;
  uint8 private _lastNft;
  mapping(uint8 => address) private _factories;
  mapping(uint8 => mapping(address => uint256)) private _prices;
  mapping(address => uint256) public proceedsBalances;
  mapping(address => bool) public paymentTokens;

  modifier onlyFactory(uint8 nftId) {
    if (nftIdByFactory(_msgSender()) != nftId) revert NotAFactoryForThisNFT(nftId);
    _;
  }

  function initialize() public initializer {
    __UUPSUpgradableTemplate_init();
  }

  function setPaymentToken(address paymentToken, bool active) external onlyOwner {
    if (active) {
      if (!paymentToken.isContract()) revert NotAContract();
      paymentTokens[paymentToken] = true;
    } else if (!paymentTokens[paymentToken]) {
      delete paymentTokens[paymentToken];
    }
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

  function setPrice(
    uint8 nftId,
    address paymentToken,
    uint256 price
  ) external onlyOwner {
    if (address(_nfts[nftId]) == address(0)) revert NFTNotFound();
    if (!paymentTokens[paymentToken]) revert InvalidPaymentToken();
    _prices[nftId][paymentToken] = price;
    emit NewPriceFor(nftId, paymentToken, price);
  }

  function getPrice(uint8 nftId, address paymentToken) external view returns (uint256) {
    return _prices[nftId][paymentToken];
  }

  function nftIdByFactory(address factory) public view returns (uint8) {
    for (uint8 i = 0; i < _lastNft + 1; i++) {
      if (_factories[i] == factory) {
        return i;
      }
    }
    return 0;
  }

  function buyTokens(
    uint8 nftId,
    address paymentToken,
    uint256 amount
  ) external payable {
    if (!paymentTokens[paymentToken]) revert InvalidPaymentToken();
    uint256 tokenAmount = _prices[nftId][paymentToken].mul(amount);
    proceedsBalances[paymentToken] += tokenAmount;
    SideToken(paymentToken).transferFrom(_msgSender(), address(this), tokenAmount);
    _nfts[nftId].mint(_msgSender(), amount);
  }

  function withdrawProceeds(
    address beneficiary,
    address paymentToken,
    uint256 amount
  ) public onlyOwner {
    if (amount == 0) {
      amount = proceedsBalances[paymentToken];
    }
    if (amount > proceedsBalances[paymentToken]) revert InsufficientFunds();
    proceedsBalances[paymentToken] -= amount;
    SideToken(paymentToken).transferFrom(address(this), beneficiary, amount);
  }
}
