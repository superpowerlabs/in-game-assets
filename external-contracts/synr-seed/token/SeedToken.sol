// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "../../../contracts/soliutils/UUPSUpgradableTemplate.sol";
import "./SideToken.sol";

contract SeedToken is SideToken, UUPSUpgradableTemplate {
  function initialize() public initializer {
    __UUPSUpgradableTemplate_init();
    __SideToken_init("Mobland Seed Token", "SEED");
  }
}
