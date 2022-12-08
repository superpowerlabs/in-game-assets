// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "../soliutils/UUPSUpgradableTemplate.sol";
import "./SideTokenMock.sol";

contract SeedTokenMock is SideTokenMock, UUPSUpgradableTemplate {
  function initialize() public initializer {
    __UUPSUpgradableTemplate_init();
    __SideToken_init("Mobland Seed Token", "SEED");
  }
}
