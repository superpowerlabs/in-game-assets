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
import "./WhitelistSlot.sol";

//import "hardhat/console.sol";

contract NftFactory is UUPSUpgradableTemplate {
  using AddressUpgradeable for address;
  using SafeMathUpgradeable for uint256;

  event NewPriceFor(uint8 nftId, address paymentToken, uint256 whitelistPrice, uint256 price);
  event FactorySetFor(uint8 nftId, address factory);
  event FactoryRemovedFor(uint8 nftId, address factory);
  event NewNftForSale(uint8 nftId, address nft);
  event NftRemovedFromSale(uint8 nftId, address nft);
  event NewSale(uint8 nftId, uint16 amountForSale);
  event EndSale(uint8 nftId);

  error NotAFactoryForThisNFT(uint256 id);
  error NotAContract();
  error NFTAlreadySet();
  error NFTNotFound();
  error FactoryNotFound();
  error InsufficientPayment();
  error InsufficientFunds();
  error TransferFailed();
  error InvalidPaymentToken();
  error ASaleIsActiveForThisNFT();
  error SaleEnded();
  error NotEnoughTokenForSale();
  error SaleNotActive();
  error NotEnoughWLSlots();

  struct Sale {
    uint16 amountForSale;
    uint16 soldTokens;
    uint32 startAt;
    uint32 whitelistUntil;
    uint16 whitelistedId;
    address[] acceptedTokens;
  }

  mapping(uint8 => ISuperpowerNFT) private _nfts;
  mapping(address => uint8) private _nftsByAddress;
  uint8 private _lastNft;
  mapping(uint8 => mapping(address => uint256)) private _wlPrices;
  mapping(uint8 => mapping(address => uint256)) private _prices;
  mapping(address => uint256) public proceedsBalances;
  mapping(address => bool) public paymentTokens;
  mapping(uint8 => Sale) internal _sales;
  WhitelistSlot private _wl;

  function initialize() public initializer {
    __UUPSUpgradableTemplate_init();
  }

  function setWl(address wl) external onlyOwner {
    if (!wl.isContract()) revert NotAContract();
    _wl = WhitelistSlot(wl);
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
    _nftsByAddress[nft] = ++_lastNft;
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

  function newSale(
    uint8 nftId,
    uint16 amountForSale,
    uint32 startAt,
    uint32 whitelistUntil,
    uint16 whitelistedId,
    address[] memory acceptedTokens
  ) external onlyOwner {
    if (_sales[nftId].amountForSale != _sales[nftId].soldTokens) revert ASaleIsActiveForThisNFT();
    _sales[nftId] = Sale({
      amountForSale: amountForSale,
      soldTokens: 0,
      startAt: startAt,
      whitelistUntil: whitelistUntil,
      whitelistedId: whitelistedId,
      acceptedTokens: acceptedTokens
    });
    emit NewSale(nftId, amountForSale);
  }

  function endSale(uint8 nftId) external onlyOwner {
    if (_sales[nftId].amountForSale > 0) {
      delete _sales[nftId];
      emit EndSale(nftId);
    }
  }

  function setPrice(
    uint8 nftId,
    address paymentToken,
    uint256 wlPrice,
    uint256 price
  ) external onlyOwner {
    if (address(_nfts[nftId]) == address(0)) revert NFTNotFound();
    if (!paymentTokens[paymentToken]) revert InvalidPaymentToken();
    _wlPrices[nftId][paymentToken] = wlPrice;
    _prices[nftId][paymentToken] = price;
    emit NewPriceFor(nftId, paymentToken, wlPrice, price);
  }

  function getPrice(uint8 nftId, address paymentToken) external view returns (uint256) {
    return _prices[nftId][paymentToken];
  }

  function getWlPrice(uint8 nftId, address paymentToken) external view returns (uint256) {
    return _wlPrices[nftId][paymentToken];
  }

  function getSale(uint8 nftId) external view returns (Sale memory) {
    return _sales[nftId];
  }

  function getSalePaymentTokens(uint8 nftId) external view returns (address[] memory) {
    return _sales[nftId].acceptedTokens;
  }

  function buyTokens(
    uint8 nftId,
    address paymentToken,
    uint256 amount
  ) external payable {
    if (!paymentTokens[paymentToken]) revert InvalidPaymentToken();
    if (_sales[nftId].amountForSale == 0) revert SaleNotActive();
    if (_sales[nftId].soldTokens == _sales[nftId].amountForSale) revert SaleEnded();
    if (amount > _sales[nftId].amountForSale - _sales[nftId].soldTokens) revert NotEnoughTokenForSale();
    uint256 tokenAmount;
    // solhint-disable-next-line not-rely-on-time
    bool isWl = block.timestamp < _sales[nftId].whitelistUntil;
    if (isWl) {
      if (_wl.balanceOf(_msgSender(), _sales[nftId].whitelistedId) < amount) revert NotEnoughWLSlots();
      tokenAmount = _wlPrices[nftId][paymentToken].mul(amount);
    } else {
      tokenAmount = _prices[nftId][paymentToken].mul(amount);
    }
    proceedsBalances[paymentToken] += tokenAmount;
    _sales[nftId].soldTokens += uint16(amount);
    SideToken(paymentToken).transferFrom(_msgSender(), address(this), tokenAmount);
    _nfts[nftId].mint(_msgSender(), amount);
    if (isWl) {
      _wl.burn(_msgSender(), _sales[nftId].whitelistedId, amount);
    }
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
