// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./SideToken.sol";

contract SeedToken is SideToken, UUPSUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize() public initializer {
    __SideToken_init("Mobland Seed Token", "SEED");
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
    emit ImplementationUpgraded(newImplementation);
  }
}
