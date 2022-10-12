// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../EXTERNAL/synr-seed/token/SideToken.sol";

contract SeedTokenMock is SideToken, UUPSUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize() public initializer {
    __SideToken_init("Mobland Seed Token", "SEED");
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

  function setMinter(address minter, bool enabled) external virtual override onlyOwner {
    //    require(minter.isContract(), "SideToken: minter is not a contract");
    minters[minter] = enabled;
  }
}
