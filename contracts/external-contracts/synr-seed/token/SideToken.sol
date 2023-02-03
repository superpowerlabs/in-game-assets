// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "../utils/Versionable.sol";

contract SideToken is Versionable, Initializable, OwnableUpgradeable, ERC20Upgradeable, ERC20BurnableUpgradeable {
  using AddressUpgradeable for address;

  mapping(address => bool) public minters;

  modifier onlyMinter() {
    require(minters[_msgSender()], "SideToken: not a minter");
    _;
  }

  // solhint-disable-next-line
  function __SideToken_init(string memory name, string memory symbol) internal initializer {
    __ERC20_init(name, symbol);
    __Ownable_init();
  }

  function mint(address to, uint256 amount) public virtual onlyMinter {
    _mint(to, amount);
  }

  function setMinter(address minter, bool enabled) external virtual onlyOwner {
    require(minter.isContract(), "SideToken: minter is not a contract");
    minters[minter] = enabled;
  }

  uint256[50] private __gap;
}
