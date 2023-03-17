// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Author: Francesco Sullo <francesco@sullo.co>
// (c) 2022+ SuperPower Labs Inc.

import "./IUserSimplified.sol";
import "./IAsset.sol";

interface IGamePool is IUserSimplified {
  event Harvested(address user, uint256 amount, uint64 opId);
  event NewDepositAndPay(uint64 depositId, address user, address otherUser);
  event NewDeposit(uint64 depositId, address user, uint8 tokenType, uint256 amount);
  event AssetStaked(address from, uint8 tokenType, uint16 tokenId);
  event AssetUnstaked(address to, uint8 tokenType, uint16 tokenId);
  event WithdrawnFT(uint8 tokenType, uint256 amount, address beneficiary);

  error turfNotERC721();
  error farmNotERC721();
  error seedNotSEED();
  error budNotBUD();
  error turfAlreadyLocked();
  error farmAlreadyLocked();
  error invalidTokenType();
  error invalidPrimarySignature();
  error invalidSecondarySignature();
  error assetNotFound();
  error turfNotLocked();
  error farmNotLocked();
  error signatureAlreadyUsed();
  error invalidRecipient();
  error invalidNFT();
  error harvestingExpired();
  error amountNotAvailable();
  error unsupportedNFT();
  error depositAlreadyExists();

  /**
      @dev to have a quick vision of the TVL
    */
  struct Conf {
    uint16 turfAmount;
    uint16 farmAmount;
    uint16 burningPoints;
  }

  /**
  @dev Used to recover a Deposit by tokenType and tokenId
  */
  struct TokenData {
    address owner;
    uint16 depositIndex;
  }

  function setConf(uint16 burningPoints) external;

  /**
      @dev Stakes an asset
      @param tokenType The type of the asset (Turf, Farm...)
      @param tokenId The id of the NFT to be staked
     */
  function stakeAsset(uint8 tokenType, uint16 tokenId) external;

  /**
      @dev Unstakes an asset
      @param tokenType The type of the asset (Turf, Farm...)
      @param tokenId The id of the NFT to be unstaked
      @param currentDepositId The id of the current deposit
      @param signature0 The signature of validator0 approving the transaction
      @param signature1 The signature of validator1 approving the transaction
     */
  function unstakeAsset(
    uint8 tokenType,
    uint16 tokenId,
    uint16 currentDepositId,
    uint256 randomNonce,
    bytes calldata signature0,
    bytes calldata signature1
  ) external;

  /**
      @dev Get a deposit by its unique ID. We do not use the index, because
        the user can have many deposits and during the unstake we will reorganize
        the order of the array in order to optimize space. So, the only value that
        remains constant is the id of the deposit.
      @param user The address of the user
      @param tokenType The type of the token
      @param tokenId The id of the token
      @return the deposit's index
    */
  function getStakeIndexByTokenId(
    address user,
    uint8 tokenType,
    uint256 tokenId,
    bool onlyActive
  ) external view returns (uint256, bool);

  /**
    @dev Get a deposit by its index. This should be public and callable inside
      the contract, as long as the index does not change.
    @param user The address of the user
    @param tokenType The type of the token
    @param index The index of the deposit
    @return the deposit
    */
  function getStakeByIndex(
    address user,
    uint8 tokenType,
    uint256 index
  ) external view returns (Stake memory);

  function getUserDeposits(address user) external view returns (Deposit[] memory);

  /**
      @dev returns the number of active deposits
      @return the number of active deposits
    */
  function getNumberOfStakes(address user, uint8 tokenType) external view returns (uint256);

  /**
    @dev Get a user conf
    @param user The address of the user
    @return the user primary parameters
    */
  function getUserStakes(address user, uint8 tokenType) external view returns (Stake[] memory);

  function depositSeed(
    uint256 amount,
    uint64 depositId,
    uint256 randomNonce,
    bytes calldata signature0
  ) external;

  function depositBud(
    uint256 amount,
    uint64 depositId,
    uint256 randomNonce,
    bytes calldata signature0
  ) external;

  function depositSeedAndPayOtherUser(
    uint256 amount,
    uint64 depositId,
    uint8 nftTokenType,
    address recipient,
    uint256 randomNonce,
    bytes calldata signature0
  ) external;

  function depositByIndex(address user, uint256 index) external view returns (Deposit memory);

  function numberOfDeposits(address user) external view returns (uint256);

  function depositById(uint64 depositId) external view returns (Deposit memory);

  function depositByIdAndUser(uint64 depositId) external view returns (Deposit memory, address);

  function harvest(
    uint256 amount,
    uint256 deadline,
    uint256 randomNonce,
    uint64 opId,
    bytes calldata signature0,
    bytes calldata signature1
  ) external;

  function withdrawFT(
    uint8 tokenType,
    uint256 amount,
    address beneficiary
  ) external;

  function initializeTurf(uint256 turfId) external;

  function updateTurfAttributes(
    uint256 tokenId,
    IAsset.TurfAttributes calldata attributes,
    uint256 randomNonce,
    bytes calldata signature0,
    bytes calldata signature1
  ) external;

  function getTurfAttributes(uint256 turfId) external view returns (IAsset.TurfAttributes memory);

  function initializeFarm(uint256 farmId) external;

  function updateFarmAttributes(
    uint256 tokenId,
    IAsset.FarmAttributes calldata attributes,
    uint256 randomNonce,
    bytes calldata signature0,
    bytes calldata signature1
  ) external;

  function getFarmAttributes(uint256 farmId) external view returns (IAsset.FarmAttributes memory);

  function hashHarvesting(
    address user,
    uint256 amount,
    uint256 deadline,
    uint256 randomNonce,
    uint64 opId
  ) external view returns (bytes32);

  function hashDeposit(
    address user,
    uint256 amount,
    uint256 depositId,
    uint256 randomNonce
  ) external view returns (bytes32);

  function hashDepositAndPay(
    address user,
    uint256 amount,
    uint64 depositId,
    uint8 nftTokenType,
    address recipient,
    uint256 randomNonce
  ) external view returns (bytes32);

  function hashFarmAttributes(
    uint256 tokenId,
    IAsset.FarmAttributes calldata attributes,
    uint256 randomNonce
  ) external view returns (bytes32);

  function hashTurfAttributes(
    uint256 tokenId,
    IAsset.TurfAttributes calldata attributes,
    uint256 randomNonce
  ) external view returns (bytes32);
}
