// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IUserSimplified {
  event Staked(address indexed user, uint16 indexed mainIndex);
  event Unstaked(address indexed user, uint16 indexed mainIndex);

  struct Stake {
    uint16 tokenId;
    uint32 lockedAt;
    uint32 unlockedAt;
  }

  struct Deposit {
    /*
    The depositId is commented because it would break the
    upgradeability. Next time we do a full re-deployment in testnet
    we can make the id explicit.
    */
    // uint32 depositId;
    uint8 tokenType;
    uint256 amount;
    uint32 depositedAt;
  }

  struct DepositInfo {
    address user;
    uint16 index;
  }

  /**
   @dev Data structure representing token holder using a pool
  */
  struct User {
    // this is increased during deposits and decreased when used
    uint256 seedAmount;
    uint256 budAmount;
    mapping(uint8 => Stake[]) stakes;
    Deposit[] deposits;
  }
}
