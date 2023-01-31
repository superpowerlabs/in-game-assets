// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../external-contracts/synr-seed/token/SideToken.sol";

contract SideTokenMock2 is SideToken {
  function mint(address to, uint256 amount) public override {
    _mint(to, amount);
  }
}
