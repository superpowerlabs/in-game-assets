// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author : Francesco Sullo < francesco@superpower.io>
// (c) Superpower Labs Inc.

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "../external-contracts/synr-seed/token/SeedToken.sol";
import "./interfaces/ISuperpowerNFT.sol";
import "./soliutils/UUPSUpgradableTemplate.sol";
import "./WhitelistSlot.sol";

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
  error SaleNotFoundMaybeEnded();
  error NotEnoughTokenForSale();
  error NotEnoughWLSlots();
  error InconsistentArrays();
  error RepeatedAcceptedToken();

  struct Sale {
    uint16 amountForSale;
    uint16 soldTokens;
    uint32 startAt;
    uint32 whitelistUntil;
    uint16 whitelistedId;
    address[] acceptedTokens;
    uint256[] wlPrices;
    uint256[] prices;
  }

  mapping(uint8 => ISuperpowerNFT) private _nfts;
  mapping(address => uint8) private _nftsByAddress;
  uint8 private _lastNft;
  mapping(address => uint256) public proceedsBalances;
  mapping(address => bool) public paymentTokens;
  mapping(uint8 => Sale) public sales;
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

  function getNftIdByAddress(address nft) external view returns (uint8) {
    return _nftsByAddress[nft];
  }

  function getNftAddressById(uint8 nftId) external view returns (address) {
    return address(_nfts[nftId]);
  }

  function getPaymentTokenSymbol(address paymentToken) external view returns (string memory) {
    return SeedToken(paymentToken).symbol();
  }

  function newSale(
    uint8 nftId,
    uint16 amountForSale,
    uint32 startAt,
    uint32 whitelistUntil,
    uint16 whitelistedId,
    address[] memory acceptedTokens,
    uint256[] memory wlPrices,
    uint256[] memory prices
  ) external onlyOwner {
    if (sales[nftId].amountForSale != sales[nftId].soldTokens) revert ASaleIsActiveForThisNFT();
    if (acceptedTokens.length != wlPrices.length || wlPrices.length != prices.length) revert InconsistentArrays();
    for (uint256 i = 0; i < acceptedTokens.length; i++) {
      if (!paymentTokens[acceptedTokens[i]]) revert InvalidPaymentToken();
      for (uint256 j = 0; j < acceptedTokens.length; j++) {
        if (j == i) continue;
        if (acceptedTokens[i] == acceptedTokens[j]) revert RepeatedAcceptedToken();
      }
    }
    sales[nftId] = Sale({
      amountForSale: amountForSale,
      soldTokens: 0,
      startAt: startAt,
      whitelistUntil: whitelistUntil,
      whitelistedId: whitelistedId,
      acceptedTokens: acceptedTokens,
      wlPrices: wlPrices,
      prices: prices
    });
    emit NewSale(nftId, amountForSale);
  }

  function endSale(uint8 nftId) external onlyOwner {
    if (sales[nftId].amountForSale > 0) {
      delete sales[nftId];
      emit EndSale(nftId);
    }
  }

  function updatePrice(
    uint8 nftId,
    address paymentToken,
    uint256 wlPrice,
    uint256 price
  ) external onlyOwner {
    if (address(_nfts[nftId]) == address(0)) revert NFTNotFound();
    if (!paymentTokens[paymentToken]) revert InvalidPaymentToken();
    if (sales[nftId].amountForSale == 0) revert SaleNotFoundMaybeEnded();
    for (uint256 i = 0; i < sales[nftId].acceptedTokens.length; i++) {
      if (sales[nftId].acceptedTokens[i] == paymentToken) {
        sales[nftId].wlPrices[i] = wlPrice;
        sales[nftId].prices[i] = price;
        emit NewPriceFor(nftId, paymentToken, wlPrice, price);
        break;
      }
    }
  }

  function getSale(uint8 nftId) external view returns (Sale memory) {
    return sales[nftId];
  }

  function getPrice(uint8 nftId, address paymentToken) public view returns (uint256) {
    for (uint256 i = 0; i < sales[nftId].acceptedTokens.length; i++) {
      if (sales[nftId].acceptedTokens[i] == paymentToken) {
        return sales[nftId].prices[i];
      }
    }
    revert NFTNotFound();
  }

  function getWlPrice(uint8 nftId, address paymentToken) public view returns (uint256) {
    for (uint256 i = 0; i < sales[nftId].acceptedTokens.length; i++) {
      if (sales[nftId].acceptedTokens[i] == paymentToken) {
        return sales[nftId].wlPrices[i];
      }
    }
    revert NFTNotFound();
  }

  function buyTokens(
    uint8 nftId,
    address paymentToken,
    uint256 amount
  ) external payable {
    if (!paymentTokens[paymentToken]) revert InvalidPaymentToken();
    if (sales[nftId].amountForSale == 0) revert SaleNotFoundMaybeEnded();
    if (sales[nftId].soldTokens == sales[nftId].amountForSale) revert SaleNotFoundMaybeEnded();
    if (amount > sales[nftId].amountForSale - sales[nftId].soldTokens) revert NotEnoughTokenForSale();
    uint256 tokenAmount;
    // solhint-disable-next-line not-rely-on-time
    bool isWl = block.timestamp < sales[nftId].whitelistUntil;
    if (isWl) {
      if (_wl.balanceOf(_msgSender(), sales[nftId].whitelistedId) < amount) revert NotEnoughWLSlots();
      tokenAmount = getWlPrice(nftId, paymentToken);
    } else {
      tokenAmount = getPrice(nftId, paymentToken);
    }
    proceedsBalances[paymentToken] += tokenAmount;
    sales[nftId].soldTokens += uint16(amount);
    SideToken(paymentToken).transferFrom(_msgSender(), address(this), tokenAmount);
    _nfts[nftId].mint(_msgSender(), amount);
    if (isWl) {
      _wl.burn(_msgSender(), sales[nftId].whitelistedId, amount);
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
