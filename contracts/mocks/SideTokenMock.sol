// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "../../external-contracts/synr-seed/token/SideToken.sol";

contract SideTokenMock is SideToken {
  function mint(address to, uint256 amount) public override {
    _mint(to, amount);
  }
}
