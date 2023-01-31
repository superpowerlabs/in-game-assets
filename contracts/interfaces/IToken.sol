// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Author: Francesco Sullo <francesco@superpower.io>

interface IToken {
  function symbol() external view returns (string memory);

  function burn(uint256 amount) external;

  function balanceOf(address account) external view returns (uint256);

  function transfer(address to, uint256 amount) external returns (bool);

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) external returns (bool);

  function mint(address to, uint256 amount) external;
}
