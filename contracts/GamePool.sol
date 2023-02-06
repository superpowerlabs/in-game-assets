// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Author: Francesco Sullo <francesco@sullo.co>
// (c) 2022+ SuperPower Labs Inc.

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "./interfaces/IAttributablePlayer.sol";

import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import "./utils/UUPSUpgradableTemplate.sol";
import "./utils/ERC721Receiver.sol";

import "./utils/Constants.sol";
import "./interfaces/IGamePool.sol";
import "./interfaces/IToken.sol";
import "./interfaces/IAsset.sol";
import "./utils/SignableStakes.sol";

//import "hardhat/console.sol";

contract GamePool is IGamePool, SignableStakes, Constants, UUPSUpgradableTemplate, IAttributablePlayer {
  using SafeMathUpgradeable for uint256;

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

  Conf public conf;
  mapping(address => User) internal _users;
  mapping(bytes32 => bool) private _usedSignatures;

  IAsset public turfToken;
  IAsset public farmToken;
  IToken public seedToken;
  IToken public budToken;

  // This is not used anymore but it cannot be removed because
  // it would alter the storage and the contract would not be upgradable anymore
  mapping(uint8 => mapping(uint16 => TokenData)) internal _stakedByTokenId;

  mapping(uint64 => DepositInfo) private _depositsById;

  function _equalString(string memory a, string memory b) internal pure returns (bool) {
    return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
  }

  /// @notice Initializes the contract
  /// @dev it will revert if the TURF or FARM token is not ERC721
  ///      or if the seed or bud token symbols are not matching
  /// @param turf address of the TURF token
  /// @param farm address of the FARM token
  /// @param seed address of the SEED token
  /// @param bud address of the BUD token
  function initialize(
    address turf,
    address farm,
    address seed,
    address bud
  ) public initializer {
    __UUPSUpgradableTemplate_init();
    __Signable_init();
    if (!IERC165Upgradeable(turf).supportsInterface(type(IERC721Upgradeable).interfaceId)) revert turfNotERC721();
    if (!IERC165Upgradeable(farm).supportsInterface(type(IERC721Upgradeable).interfaceId)) revert farmNotERC721();
    turfToken = IAsset(turf);
    farmToken = IAsset(farm);
    seedToken = IToken(seed);
    if (!_equalString(seedToken.symbol(), "SEED")) revert seedNotSEED();
    budToken = IToken(bud);
    if (!_equalString(budToken.symbol(), "BUD")) revert budNotBUD();
    conf.burningPoints = 7000; // 70%
  }

  function setConf(uint16 burningPoints) external override onlyOwner {
    conf.burningPoints = burningPoints;
  }

  /// @notice Stakes a token of type TURF or FARM
  /// @dev it will revert if GamePool not approved to spend the token
  ///      and/or if GamePool is not an authorized locker
  /// @param tokenType uint for type of token, should be TURF or FARM
  /// @param tokenId uint for the tokenId of the token to stake
  function stakeAsset(uint8 tokenType, uint16 tokenId) external override {
    if (tokenType == TURF) {
      if (turfToken.locked(tokenId)) revert turfAlreadyLocked();
      conf.turfAmount++;
      turfToken.lock(tokenId);
    } else if (tokenType == FARM) {
      if (farmToken.locked(tokenId)) revert farmAlreadyLocked();
      conf.farmAmount++;
      farmToken.lock(tokenId);
    } else {
      revert unsupportedNFT();
    }
    Stake memory stake = Stake({tokenId: uint16(tokenId), lockedAt: uint32(block.timestamp), unlockedAt: 0});
    _users[_msgSender()].stakes[tokenType].push(stake);
    emit AssetStaked(_msgSender(), tokenType, tokenId);
  }

  /// @notice Unstakes a token of type TURF or FARM
  /// @dev This function revert with "signatureAlreadyUsed" in
  ///      _saveSignatureAsUsed if the signature was already used
  ///      It will revert if the token is not staked by the user
  ///      in V1, the signature0 is necessary because we cannot check inside this contract if the
  ///      staked asset is used somewhere. So, we let the game to decide that and guarantee
  ///      that the asset can be unstaked.
  /// @param tokenType uint for type of token, should be TURF or FARM
  /// @param tokenId tutokenId of the token to unstake
  /// @param stakeIndex index of the stake in the stakes array
  /// @param randomNonce random nonce
  /// @param signature0 single use signature from validator 0
  /// @param signature1 single use signature from validator 1
  function unstakeAsset(
    uint8 tokenType,
    uint16 tokenId,
    uint16 stakeIndex,
    uint256 randomNonce,
    bytes calldata signature0,
    bytes calldata signature1
  ) external override {
    if (tokenType != TURF && tokenType != FARM) revert invalidTokenType();
    if (!isSignedByAValidator(0, 2, hashUnstake(tokenType, tokenId, stakeIndex, randomNonce), signature0))
      revert invalidPrimarySignature();
    if (!isSignedByAValidator(1, 3, hashUnstake(tokenType, tokenId, stakeIndex, randomNonce), signature1))
      revert invalidSecondarySignature();
    _saveSignatureAsUsed(signature0);
    _saveSignatureAsUsed(signature1);
    (uint256 index, bool found) = getStakeIndexByTokenId(_msgSender(), tokenType, tokenId, true);
    if (!found) revert assetNotFound();
    _users[_msgSender()].stakes[tokenType][index].unlockedAt = uint32(block.timestamp);
    if (tokenType == TURF) {
      if (!turfToken.locked(tokenId)) revert turfNotLocked();
      conf.turfAmount--;
      turfToken.unlock(tokenId);
    } else {
      // shouldn't we explicitly check for else if tokenType == FARM?
      if (!farmToken.locked(tokenId)) revert farmNotLocked();
      conf.farmAmount--;
      farmToken.unlock(tokenId);
    }
    emit AssetUnstaked(_msgSender(), tokenType, tokenId);
  }

  /// @notice Returns the state of a stake
  /// @param _stake Stake struct to test
  /// @param _tokenId uint for the tokenId of the token
  /// @param _onlyActive boolean to restrict the search to active stakes
  /// @return true if the stake is the one we are looking for with a matching state
  ///         false if the stake is not the one we are looking for or if the state is not matching
  function _checkStakeState(
    Stake memory _stake,
    uint256 _tokenId,
    bool _onlyActive
  ) internal pure returns (bool) {
    bool state = uint16(_stake.tokenId) == _tokenId && _stake.lockedAt != 0 && (!_onlyActive || _stake.unlockedAt == 0);
    return state;
  }

  /// @notice Returns the index of the stake in the _user[].stakes array
  /// @param user address of the user
  /// @param tokenType uint for type of token
  /// @param tokenId uint for the tokenId of the token
  /// @param onlyActive boolean to restrict the search to active stakes
  /// @return index of the stake in the _user[].stakes array
  /// @return true if the stake was found, false is not
  function getStakeIndexByTokenId(
    address user,
    uint8 tokenType,
    uint256 tokenId,
    bool onlyActive
  ) public view override returns (uint256, bool) {
    for (uint256 i; i < _users[user].stakes[tokenType].length; i++) {
      Stake memory stake = _users[user].stakes[tokenType][i];
      if (_checkStakeState(stake, tokenId, onlyActive)) {
        return (i, true);
      }
    }
    return (0, false);
  }

  /// @notice Returns the stake of a token, returns an empty stake if not found
  /// @param user address of the user
  /// @param tokenType uint for type of token
  /// @param index index of the stake in the _sers[].stakes array
  function getStakeByIndex(
    address user,
    uint8 tokenType,
    uint256 index
  ) external view override returns (Stake memory) {
    if (_users[user].stakes[tokenType].length <= index) {
      Stake memory emptyStake;
      return emptyStake;
    } else {
      return _users[user].stakes[tokenType][index];
    }
  }

  /// @notice Returns the number of stakes for a user and for a token type
  /// @param user address of the user
  /// @param tokenType uint for type of token
  /// @return number of stakes for a user and for a token type
  function getNumberOfStakes(address user, uint8 tokenType) external view override returns (uint256) {
    return _users[user].stakes[tokenType].length;
  }

  /// @notice Returns the deposits for a user
  /// @param user address of the user
  /// @return array of Deposit structs
  function getUserDeposits(address user) external view override returns (Deposit[] memory) {
    return _users[user].deposits;
  }

  /// @notice Returns the amount of token staked by the user by type
  /// @param user address of the user
  /// @param tokenType uint8 for type of token
  /// @return amount of token staked by the user by type
  function getUserStakes(address user, uint8 tokenType) external view override returns (Stake[] memory) {
    return _users[user].stakes[tokenType];
  }

  /// @notice Marks a signature as used if not already used
  /// @dev This function revert with "signatureAlreadyUsed" if signature already used
  /// @param _signature bytes of the signature to mark as used
  function _saveSignatureAsUsed(bytes memory _signature) internal {
    bytes32 key = bytes32(keccak256(abi.encodePacked(_signature)));
    if (_usedSignatures[key]) revert signatureAlreadyUsed();
    _usedSignatures[key] = true;
  }

  /// @notice Deposits SEEDs to message sender
  /// @dev This function revert with "signatureAlreadyUsed" in
  ///      _saveSignatureAsUsed if the signature was already used
  /// @param amount uint256 for the amount of SEEDs to deposit
  /// @param depositId uint64 for the deposit id.
  /// @param randomNonce uint256 for the random nonce
  /// @param signature0 bytes for the signature of the validator
  function depositSeed(
    uint256 amount,
    uint64 depositId,
    uint256 randomNonce,
    bytes calldata signature0
  ) external override {
    if (!isSignedByAValidator(0, 2, hashDeposit(_msgSender(), amount, depositId, randomNonce), signature0))
      revert invalidPrimarySignature();
    _saveSignatureAsUsed(signature0);
    _depositFT(SEED, amount, depositId, _msgSender());
  }

  /// @notice Deposits BUDs to message sender
  /// @param amount uint256 for the amount of BUDs to deposit
  /// @param depositId uint64 for the deposit id
  /// @param randomNonce uint256 for the random nonce
  /// @param signature0 bytes for the signature of the validator
  function depositBud(
    uint256 amount,
    uint64 depositId,
    uint256 randomNonce,
    bytes calldata signature0
  ) external override {
    if (!isSignedByAValidator(0, 2, hashDeposit(_msgSender(), amount, depositId, randomNonce), signature0))
      revert invalidPrimarySignature();
    _saveSignatureAsUsed(signature0);
    _depositFT(BUD, amount, depositId, _msgSender());
  }

  /// @notice Deposits SEEDs to message sender and pays another user
  /// @dev This function revert with "signatureAlreadyUsed" in
  ///      _saveSignatureAsUsed if the signature was already used
  /// @param amount uint256 for the amount of SEEDs to deposit
  /// @param depositId uint64 for the deposit id
  /// @param nftTokenType uint8 for the type of NFT
  /// @param recipient address for the recipient of the SEEDs
  /// @param randomNonce uint256 for the random nonce
  /// @param signature0 bytes for the signature of the validator
  function depositSeedAndPayOtherUser(
    uint256 amount,
    uint64 depositId,
    uint8 nftTokenType,
    address recipient,
    uint256 randomNonce,
    bytes calldata signature0
  ) external override {
    if (
      !isSignedByValidator(
        0,
        hashDepositAndPay(_msgSender(), amount, depositId, nftTokenType, recipient, randomNonce),
        signature0
      )
    ) revert invalidPrimarySignature();
    _saveSignatureAsUsed(signature0);
    if (recipient == address(0) || recipient == address(this)) revert invalidRecipient();
    uint256 percentage = nftTokenType == TURF ? 92 : nftTokenType == FARM ? 95 : 0;
    if (percentage == 0) revert invalidNFT();
    uint256 amountToOwner = amount.mul(percentage).div(100);
    seedToken.transferFrom(_msgSender(), recipient, amountToOwner);
    _depositFT(SEED, amount.sub(amountToOwner), depositId, _msgSender());
    emit NewDepositAndPay(depositId, _msgSender(), recipient);
  }

  /// @notice Deposits amount of token to user account
  /// @dev it will revert if spend not approved or if insufficient balance
  ///      appends a Deposit to the user's deposits array _users[].deposits
  /// @param tokenType type of token to deposit
  /// @param amount amount of token to deposit
  /// @param depositId uint64 for the deposit id
  ///      The depositId is not managed in the contract, it comes
  ///      from the game app and is used to prevent replay attacks,
  ///      to identify the deposit in the game app, and manage the flow
  ///      of the game app.
  /// @param user the address of the user
  function _depositFT(
    uint8 tokenType,
    uint256 amount,
    uint64 depositId,
    address user
  ) internal {
    Deposit memory deposit = Deposit({tokenType: tokenType, amount: amount, depositedAt: uint32(block.timestamp)});
    _depositsById[depositId] = DepositInfo({index: uint16(_users[user].deposits.length), user: user});
    _users[user].deposits.push(deposit);
    if (tokenType == SEED) {
      seedToken.transferFrom(user, address(this), amount);
    } else {
      budToken.transferFrom(user, address(this), amount);
    }
    emit NewDeposit(depositId, user, tokenType, amount);
  }

  /// @notice Returns the deposit by index or an emoty deposit if index is out of bounds
  /// @param user address of the user
  /// @param index uint256 for the index of the deposit
  function depositByIndex(address user, uint256 index) public view override returns (Deposit memory) {
    if (_users[user].deposits.length <= index) {
      Deposit memory emptyDeposit;
      return emptyDeposit;
    } else {
      return _users[user].deposits[index];
    }
  }

  /// @notice Returns the number of deposits for user
  /// @param user address of the user
  /// @return uint256 for the number of deposits
  function numberOfDeposits(address user) external view override returns (uint256) {
    return _users[user].deposits.length;
  }

  /// @notice Returns the deposit by id
  /// @param depositId uint64 for the deposit id
  /// @return Deposit struct
  function depositById(uint64 depositId) external view override returns (Deposit memory) {
    DepositInfo memory info = _depositsById[depositId];
    return depositByIndex(info.user, uint256(info.index));
  }

  /// @notice Returns the deposit by id and user
  /// @param depositId uint64 for the deposit id
  /// @return Deposit struct
  /// @return address of the user
  function depositByIdAndUser(uint64 depositId) external view override returns (Deposit memory, address) {
    DepositInfo memory info = _depositsById[depositId];
    return (depositByIndex(info.user, uint256(info.index)), info.user);
  }

  /// @notice Harvests amount of BUDs
  /// @dev It will revert if the deadline has passed or if the signatures are invalid
  ///      This function revert with "signatureAlreadyUsed" in
  ///      _saveSignatureAsUsed if the signature was already used
  ///      Note: the current flow relies on the validator to validate transactions, if
  ///      validators are compromised, the system is compromised as well. This is not
  ///      a viable solution in the long term. The amount of harvestable tokens should
  ///      be derived from parameters on chain that cannot be forced or exploited.
  /// @param amount amount of BUDs to mint
  /// @param deadline timestamp after which the transaction will revert
  /// @param randomNonce random nonce to prevent replay attacks (used in signing)
  /// @param opId operation id to prevent replay attacks (used in signing)
  function harvest(
    uint256 amount,
    uint256 deadline,
    uint256 randomNonce,
    uint64 opId,
    bytes calldata signature0,
    bytes calldata signature1
  ) external override {
    if (deadline <= block.timestamp) revert harvestingExpired();
    if (!isSignedByAValidator(0, 2, hashHarvesting(_msgSender(), amount, deadline, randomNonce, opId), signature0))
      revert invalidPrimarySignature();
    if (!isSignedByAValidator(1, 3, hashHarvesting(_msgSender(), amount, deadline, randomNonce, opId), signature1))
      revert invalidSecondarySignature();
    _saveSignatureAsUsed(signature0);
    _saveSignatureAsUsed(signature1);
    budToken.mint(_msgSender(), amount);
    emit Harvested(_msgSender(), amount, opId);
  }

  // THIS IS NOT USED, can we remove it?
  // /// @notice Returns true if the signature has been used before
  // /// @param signature bytes for the signature
  // function isSignatureUsed(bytes calldata signature) external view returns (bool) {
  //   bytes32 key = bytes32(keccak256(abi.encodePacked(signature)));
  //   return _usedSignatures[key];
  // }

  /// @notice Withdraws an amount of funds in SEEDS or BUDS, or all of them if amount is 0
  /// @dev The token emits a Transfer event with the pool as the sender,
  ///      the beneficiary as the receiver and the (amount - burned) as the value
  ///      "burned" is calculated as amount * conf.burningPoints / 10000
  /// @param tokenType The type of token to withdraw
  /// @param amount The amount of tokens to withdraw
  /// @param beneficiary The address to which the tokens will be sent
  function withdrawFT(
    uint8 tokenType,
    uint256 amount,
    address beneficiary
  ) external override onlyOwner {
    uint256 balance;
    if (tokenType == SEED) {
      balance = seedToken.balanceOf(address(this));
    } else {
      balance = budToken.balanceOf(address(this));
    }
    if (balance < amount) revert amountNotAvailable();
    if (amount == 0) {
      amount = balance;
    }
    uint256 burned = amount.mul(conf.burningPoints).div(10000);
    if (tokenType == SEED) {
      seedToken.burn(burned);
      seedToken.transfer(beneficiary, amount.sub(burned));
    } else {
      budToken.burn(burned);
      budToken.transfer(beneficiary, amount.sub(burned));
    }
    emit WithdrawnFT(tokenType, amount, beneficiary);
  }

  /// @notice Initializes the attributes of a turf token
  /// @dev This function will fail if the contract has not been
  ///      approved to spend the token.
  ///      For more details see IAttributable.sol
  /// @param turfId The id of the token
  function initializeTurf(uint256 turfId) external override onlyOwner {
    turfToken.initializeAttributesFor(turfId, address(this));
  }

  /// @notice Updates the attributes of a turf token
  /// @dev This function revert with "signatureAlreadyUsed" in
  ///      _saveSignatureAsUsed if the signature was already used
  ///      note:that if attributes.level is 0, the player de-authorizes itself
  ///      look at SuperpowerNFTBase.sol for more details
  /// @param tokenId The id of the token
  /// @param attributes The attributes to update
  /// @param randomNonce random nonce to prevent replay attacks (used in signing)
  /// @param signature0 signature of the first validator
  /// @param signature1 signature of the second validator
  function updateTurfAttributes(
    uint256 tokenId,
    IAsset.TurfAttributes calldata attributes,
    uint256 randomNonce,
    bytes calldata signature0,
    bytes calldata signature1
  ) external override {
    if (!isSignedByAValidator(0, 2, hashTurfAttributes(tokenId, attributes, randomNonce), signature0))
      revert invalidPrimarySignature();
    if (!isSignedByAValidator(1, 3, hashTurfAttributes(tokenId, attributes, randomNonce), signature1))
      revert invalidSecondarySignature();
    _saveSignatureAsUsed(signature0);
    _saveSignatureAsUsed(signature1);

    turfToken.updateAttributes(tokenId, 0, uint256(attributes.level));
  }

  /// @notice Returns the attributes of a turf token
  /// @param turfId The id of the token
  function getTurfAttributes(uint256 turfId) external view override returns (IAsset.TurfAttributes memory) {
    return IAsset.TurfAttributes({level: uint8(turfToken.attributesOf(turfId, address(this), 0))});
  }

  /// @notice Initializes the attributes of a farm
  /// @dev This function will fail if the contract has not been
  ///      approved to spend the token.
  /// @param farmId The id of the token
  function initializeFarm(uint256 farmId) external override onlyOwner {
    // This will fail if the the contract has not been approved
    // to spend the token
    farmToken.initializeAttributesFor(farmId, address(this));
  }

  /// @notice Updates the attributes of a farm token
  /// @dev This function revert with "signatureAlreadyUsed" in
  ///      _saveSignatureAsUsed if the signature was already used
  ///      note: that if attributes.level is 0, the player de-authorizes itself
  ///      look at SuperpowerNFTBase.sol for more details
  ///      look at iAsset.sol for details on the attributes encoding
  /// @param tokenId The id of the token
  /// @param attributes The attributes to update
  /// @param randomNonce random nonce to prevent replay attacks (used in signing)
  /// @param signature0 signature of the first validator
  /// @param signature1 signature of the second validator
  function updateFarmAttributes(
    uint256 tokenId,
    IAsset.FarmAttributes calldata attributes,
    uint256 randomNonce,
    bytes calldata signature0,
    bytes calldata signature1
  ) external {
    if (!isSignedByAValidator(0, 2, hashFarmAttributes(tokenId, attributes, randomNonce), signature0))
      revert invalidPrimarySignature();
    if (!isSignedByAValidator(1, 3, hashFarmAttributes(tokenId, attributes, randomNonce), signature1))
      revert invalidSecondarySignature();
    _saveSignatureAsUsed(signature0);
    _saveSignatureAsUsed(signature1);
    uint256 attributes2 = uint256(attributes.level) |
      (uint256(attributes.farmState) << 8) |
      (uint256(attributes.currentHP) << 16) |
      (uint256(attributes.weedReserves) << 48);
    farmToken.updateAttributes(tokenId, 0, attributes2);
  }

  /// @notice Returns the attributes of a farm
  /// @param farmId The id of the token
  /// @return The attributes of the farm
  function getFarmAttributes(uint256 farmId) external view returns (IAsset.FarmAttributes memory) {
    uint256 attributes = farmToken.attributesOf(farmId, address(this), 0);
    return
      IAsset.FarmAttributes({
        level: uint8(attributes),
        farmState: uint8(attributes >> 8),
        currentHP: uint32(attributes >> 16),
        weedReserves: uint32(attributes >> 48)
      });
  }

  /// @notice Returns the attributes of a token
  /// @dev Attributes encoding is specific to each token type
  /// @param _token The address of the token
  /// @param tokenId The id of the token
  /// @return string the attributes of the token encoded as a string
  function attributesOf(address _token, uint256 tokenId) external view override returns (string memory) {
    if (_token == address(turfToken)) {
      uint256 attributes = turfToken.attributesOf(tokenId, address(this), 0);
      if (attributes != 0) {
        return string(abi.encodePacked("uint8 level:", StringsUpgradeable.toString(uint8(attributes))));
      }
    } else if (_token == address(farmToken)) {
      uint256 attributes = farmToken.attributesOf(tokenId, address(this), 0);
      if (attributes != 0) {
        return
          string(
            abi.encodePacked(
              "uint8 level:",
              StringsUpgradeable.toString(uint8(attributes)),
              ";uint8 farmState:",
              StringsUpgradeable.toString(uint8(attributes >> 8)),
              ";uint32 currentHP:",
              StringsUpgradeable.toString(uint32(attributes >> 16)),
              ";uint32 weedReserves:",
              StringsUpgradeable.toString(uint32(attributes >> 48))
            )
          );
      }
    }
    return "";
  }

  /// @notice Returns a hash of the parameters adding chainId for security
  /// @param user The user address
  /// @param amount The amount of the deposit
  /// @param depositId The id of the deposit
  /// @param randomNonce random nonce
  /// @return bytes32 the hash of the parameters
  function hashDeposit(
    address user,
    uint256 amount,
    uint256 depositId,
    uint256 randomNonce
  ) public view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x01", // EIP-191
          block.chainid,
          user,
          amount,
          depositId,
          randomNonce
        )
      );
  }

  /// @notice Returns a hash of the parameters adding chainId for security
  /// @param user The user address
  /// @param amount The amount of the deposit
  /// @param depositId The id of the deposit
  /// @param nftTokenType The type of the NFT token
  /// @param recipient The recipient of the NFT token
  /// @param randomNonce random nonce
  /// @return bytes32 the hash of the parameters
  function hashDepositAndPay(
    address user,
    uint256 amount,
    uint64 depositId,
    uint8 nftTokenType,
    address recipient,
    uint256 randomNonce
  ) public view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x01", // EIP-191
          block.chainid,
          user,
          amount,
          depositId,
          nftTokenType,
          recipient,
          randomNonce
        )
      );
  }

  /// @notice Returns a hash of the parameters adding chainId for security
  /// @param user The user address
  /// @param amount The amount of the deposit
  /// @param deadline The deadline of the deposit
  /// @param randomNonce random nonce
  /// @param opId The id of the operation
  /// @return bytes32 the hash of the parameters
  function hashHarvesting(
    address user,
    uint256 amount,
    uint256 deadline,
    uint256 randomNonce,
    uint64 opId
  ) public view override returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x01", // EIP-191
          block.chainid,
          user,
          amount,
          deadline,
          randomNonce,
          opId
        )
      );
  }

  /// @notice Returns a hash of the parameters adding chainId for security
  /// @param tokenId The id of the token
  /// @param attributes The attributes of the token
  /// @param randomNonce random nonce
  /// @return bytes32 the hash of the parameters
  function hashFarmAttributes(
    uint256 tokenId,
    IAsset.FarmAttributes calldata attributes,
    uint256 randomNonce
  ) public view override returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x01", // EIP-191
          block.chainid,
          tokenId,
          attributes.level,
          attributes.farmState,
          attributes.currentHP,
          attributes.weedReserves,
          randomNonce
        )
      );
  }

  /// @notice Returns a hash of the parameters adding chainId for security
  /// @param tokenId The id of the token
  /// @param attributes The attributes of the token
  /// @param randomNonce random nonce
  /// @return bytes32 the hash of the parameters
  function hashTurfAttributes(
    uint256 tokenId,
    IAsset.TurfAttributes calldata attributes,
    uint256 randomNonce
  ) public view override returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x01", // EIP-191
          block.chainid,
          tokenId,
          attributes.level,
          randomNonce
        )
      );
  }
}
