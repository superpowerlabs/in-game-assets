// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./SideTokenMock2.sol";

contract SeedTokenMock2 is SideTokenMock2, UUPSUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize() public initializer {
    __SideToken_init("Mobland Seed Token", "SEED");
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}
