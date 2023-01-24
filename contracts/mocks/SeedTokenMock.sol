// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../utils/UUPSUpgradableTemplate.sol";
import "./SideTokenMock.sol";

contract SeedTokenMock is SideTokenMock, UUPSUpgradableTemplate {
  function initialize() public initializer onlyProxy {
    __UUPSUpgradableTemplate_init();
    __SideToken_init("Mobland Seed Token", "SEED");
  }
}
