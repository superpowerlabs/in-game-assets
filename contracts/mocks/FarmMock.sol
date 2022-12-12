// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc

import "../interfaces/ISuperpowerNFT.sol";

contract FarmMock {
  ISuperpowerNFT public nft;

  // solhint-disable-next-line func-visibility
  constructor(address nft_) {
    require(nft_.code.length > 0, "Not a contract");
    nft = ISuperpowerNFT(nft_);
  }

  function mintTokens(address to, uint256 amount) external {
    nft.mint(to, amount);
  }
}
