// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author: Francesco Sullo <francesco@sullo.co>
// (c) 2022+ SuperPower Labs Inc.

contract Versionable {
  function version() external pure virtual returns (uint256) {
    return 1;
  }
}
