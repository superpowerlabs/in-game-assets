// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Author : Francesco Sullo < francesco@superpower.io>
// (c) Superpower Labs Inc.

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "../external-contracts/synr-seed/token/SeedToken.sol";
import "./interfaces/ISuperpowerNFT.sol";
import "./utils/UUPSUpgradableTemplate.sol";
import "./WhitelistSlot.sol";

//import "hardhat/console.sol";

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
  event NewNftForSale(uint8 nftId, address nft);
  event NftRemovedFromSale(uint8 nftId, address nft);
  event NewSale(uint8 nftId, uint16 amountForSale);
  event EndSale(uint8 nftId);
  event SaleUpdated(uint8 nftId);

  error NotAContract();
  error NFTAlreadySet();
  error NFTNotFound();
  error InsufficientFunds();
  error TransferFailed();
  error InvalidPaymentToken();
  error ASaleIsActiveForThisNFT();
  error SaleNotFoundMaybeEnded();
  error SaleNotFound();
  error SaleEnded();
  error NotEnoughTokenForSale();
  error NotEnoughWLSlots();
  error InconsistentArrays();
  error RepeatedAcceptedToken();
  error InvalidAmountForSale();
  error OnlyOneTokenForTransactionInPublicSale();

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

  // The modifier onlyProxy is unnecessary. Was put there
  // to avoid a security alert produced by slither and
  // prove that that is a false positive
  function initialize()
    public
    initializer // onlyProxy
  {
    __UUPSUpgradableTemplate_init();
  }

  /// @notice Sets a whitelist
  /// @dev creates a new whitelist slot
  /// @param wl the address of the whitelist
  function setWl(address wl) external onlyOwner {
    if (!wl.isContract()) revert NotAContract();
    _wl = WhitelistSlot(wl);
  }

  /// @notice Activate or disactivate a payment token
  /// @dev activates payment token or removes it from the paymentTokens if "active" is false
  /// @param paymentToken address of the payment token
  /// @param active activate or disactivate a payment token
  function setPaymentToken(address paymentToken, bool active) external onlyOwner {
    if (active) {
      if (!paymentToken.isContract()) revert NotAContract();
      paymentTokens[paymentToken] = true;
    } else if (!paymentTokens[paymentToken]) {
      delete paymentTokens[paymentToken];
    }
  }

  /// @notice Sets a new NFT for sale
  /// @dev Emits the NewNftForSale event
  /// @param nft the token
  function setNewNft(address nft) external onlyOwner {
    if (!nft.isContract()) revert NotAContract();
    if (_nftsByAddress[nft] > 0) revert NFTAlreadySet();
    _nftsByAddress[nft] = ++_lastNft;
    _nfts[_lastNft] = ISuperpowerNFT(nft);
    emit NewNftForSale(_lastNft, nft);
  }

  /// @notice Removes an NFT from the sale
  /// @dev Emits the NftRemovedFromSale event
  /// @param nft the token
  function removeNewNft(address nft) external onlyOwner {
    if (_nftsByAddress[nft] == 0) revert NFTNotFound();
    uint8 nftId = _nftsByAddress[nft];
    delete _nfts[nftId];
    delete _nftsByAddress[nft];
    emit NftRemovedFromSale(nftId, nft);
  }

  /// @notice Get an NFT from its address
  /// @param nft the token
  function getNftIdByAddress(address nft) external view returns (uint8) {
    return _nftsByAddress[nft];
  }

  /// @notice Get a NFT address from its Id
  /// @param nftId the token Id
  function getNftAddressById(uint8 nftId) external view returns (address) {
    return address(_nfts[nftId]);
  }

  /// @notice Returns the symbol of a payment token
  /// @param paymentToken the payment token
  function getPaymentTokenSymbol(address paymentToken) external view returns (string memory) {
    return SeedToken(paymentToken).symbol();
  }

  /// @notice Creates a new Sale for an NFT
  /// @dev this function emits a "NewSale" event for the NFT
  /// @param nftId the token to be sold
  /// @param amountForSale the amount of token to be sold
  /// @param startAt the timestamp the sale starts
  /// @param whitelistUntil the timestamp the sale ends
  /// @param whitelistedId whitelist slot Id
  /// @param acceptedTokens an array of tokens accepted to buy the NFT
  /// @param wlPrices an array of whitelisted prices (one for each accepted tokens)
  /// @param prices an array of prices (one for each accepted tokens)
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
    // reverts if a sale is already active for this NFT
    if (sales[nftId].amountForSale != sales[nftId].soldTokens) revert ASaleIsActiveForThisNFT();
    if (amountForSale == 0) revert InvalidAmountForSale();
    // reverts if inconsistencies are detected in price and whitelisted price definition
    if (acceptedTokens.length != wlPrices.length || wlPrices.length != prices.length) revert InconsistentArrays();
    for (uint256 i = 0; i < acceptedTokens.length; i++) {
      if (!paymentTokens[acceptedTokens[i]]) revert InvalidPaymentToken();
      for (uint256 j = 0; j < acceptedTokens.length; j++) {
        if (j == i) continue;
        if (acceptedTokens[i] == acceptedTokens[j]) revert RepeatedAcceptedToken();
      }
    }
    if (whitelistUntil == 0) {
      // no whitelist round
      whitelistUntil = startAt;
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

  /// @notice Update an existing Sale
  /// @dev this function emits an "SaleUpdated" event for the NFT
  /// @param nftId the token of the Sale
  /// @param amountForSale a larger amount for sale
  /// @param whitelistUntil a new end of the WL period, to anticipate or delay it
  /// @param wlPrices updated prices for WL
  /// @param prices updated prices for not-WL
  function updateSale(
    uint8 nftId,
    uint16 amountForSale,
    uint32 whitelistUntil,
    uint256[] memory wlPrices,
    uint256[] memory prices
  ) external onlyOwner {
    if (sales[nftId].amountForSale > 0) {
      if (amountForSale > sales[nftId].amountForSale) {
        sales[nftId].amountForSale = amountForSale;
      }
      if (whitelistUntil != 0) {
        sales[nftId].whitelistUntil = whitelistUntil;
      }
      // an empty array is ignored
      if (wlPrices.length == sales[nftId].wlPrices.length) {
        sales[nftId].wlPrices = wlPrices;
      }
      if (prices.length == sales[nftId].prices.length) {
        sales[nftId].prices = prices;
      }
      emit SaleUpdated(nftId);
    } else {
      revert SaleNotFoundMaybeEnded();
    }
  }

  /// @notice Ends (removes) an existing Sale
  /// @dev this function emits an "EndSale" event for the NFT
  /// @param nftId the token of the Sale
  function endSale(uint8 nftId) external onlyOwner {
    if (sales[nftId].amountForSale > 0) {
      delete sales[nftId];
      emit EndSale(nftId);
    } else {
      revert SaleNotFoundMaybeEnded();
    }
  }

  /// @notice Updates the prices of an existing running  Sale
  /// @dev this function emits a "NewPriceFor" event for the NFT
  /// @param nftId the token of the Sale
  /// @param paymentToken the token to update the price for
  /// @param wlPrice whitelisted price
  /// @param price price
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

  /// @notice Gets an NFT Sale
  /// @param nftId the token of the Sale
  /// @return The struct for the sale of the NFT
  function getSale(uint8 nftId) external view returns (Sale memory) {
    return sales[nftId];
  }

  /// @notice Gets an NFT sale's price
  /// @param nftId the token of the Sale
  /// @param paymentToken the payment token the we want the price for
  /// @return The price of the NFT with this token
  function getPrice(uint8 nftId, address paymentToken) public view returns (uint256) {
    for (uint256 i = 0; i < sales[nftId].acceptedTokens.length; i++) {
      if (sales[nftId].acceptedTokens[i] == paymentToken) {
        return sales[nftId].prices[i];
      }
    }
    revert NFTNotFound();
  }

  /// @notice Gets an NFT sale's price
  /// @param nftId the token of the Sale
  /// @param paymentToken the payment token the we want the price for
  /// @return The whitelisted price of the NFT with this token
  function getWlPrice(uint8 nftId, address paymentToken) public view returns (uint256) {
    for (uint256 i = 0; i < sales[nftId].acceptedTokens.length; i++) {
      if (sales[nftId].acceptedTokens[i] == paymentToken) {
        return sales[nftId].wlPrices[i];
      }
    }
    revert NFTNotFound();
  }

  /// @notice Buy an NFT
  /// @dev Given a payment token, will use the normal price or the discounted price if whitelisted
  /// @param nftId the token of the Sale
  /// @param paymentToken the payment token to use for buying
  /// @param amount number of token to buy
  function buyTokens(
    uint8 nftId,
    address paymentToken,
    uint256 amount
  ) external payable {
    if (!paymentTokens[paymentToken]) revert InvalidPaymentToken();
    if (sales[nftId].amountForSale == 0) revert SaleNotFound();
    if (sales[nftId].soldTokens == sales[nftId].amountForSale) revert SaleEnded();
    if (amount > sales[nftId].amountForSale - sales[nftId].soldTokens) revert NotEnoughTokenForSale();
    uint256 payment;

    // solhint-disable-next-line not-rely-on-time
    bool isWl = block.timestamp < sales[nftId].whitelistUntil;
    if (isWl) {
      if (_wl.balanceOf(_msgSender(), sales[nftId].whitelistedId) < amount) revert NotEnoughWLSlots();
      payment = getWlPrice(nftId, paymentToken).mul(amount);
    } else {
      if (amount > 1) revert OnlyOneTokenForTransactionInPublicSale();
      payment = getPrice(nftId, paymentToken);
    }
    proceedsBalances[paymentToken] += payment;
    sales[nftId].soldTokens += uint16(amount);
    if (!SideToken(paymentToken).transferFrom(_msgSender(), address(this), payment)) revert TransferFailed();
    _nfts[nftId].mint(_msgSender(), amount);
    if (isWl) {
      _wl.burn(_msgSender(), sales[nftId].whitelistedId, amount);
    }
  }

  /// @notice Withdraw proceeds
  /// @dev Given a payment token, transfers amount or full balance from proceeds to an address
  /// @param beneficiary address of the beneficiary
  /// @param paymentToken the payment token to use for the transfer
  /// @param amount number to transfer
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
    if (!SideToken(paymentToken).transfer(beneficiary, amount)) revert TransferFailed();
  }
}
