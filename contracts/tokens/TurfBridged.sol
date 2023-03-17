// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc.

import "./EventPatchBridged.sol";

contract TurfBridged is EventPatchBridged {
  function initialize(string memory tokenUri) public initializer onlyProxy {
    __SuperpowerNFTBase_init("MOBLAND Turf", "mTURF", tokenUri);
  }
}
