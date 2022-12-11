// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "soliutils/contracts/UUPSUpgradableTemplate.sol";
import "./SideTokenMock.sol";

contract BUSDMock is SideTokenMock, UUPSUpgradableTemplate {
  function initialize() public initializer {
    __UUPSUpgradableTemplate_init();
    __SideToken_init("Binance USD", "BUSD");
  }
}