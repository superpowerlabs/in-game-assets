// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../WhitelistSlot.sol";

contract BurnerMock {
  WhitelistSlot public whitelist;

  function setWl(address whitelist_) external {
    require(whitelist_.code.length > 0, "Not a contract");
    whitelist = WhitelistSlot(whitelist_);
  }

  function burn(
    address account,
    uint256 id,
    uint256 amount
  ) public {
    whitelist.burn(account, id, amount);
  }
}
