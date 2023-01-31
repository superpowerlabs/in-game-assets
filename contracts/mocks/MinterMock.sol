// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Authors: Francesco Sullo <francesco@superpower.io>
// (c) Superpower Labs Inc

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ISuperpowerNFT.sol";
import "../tokens/Turf.sol";
import "../tokens/Farm.sol";

//import "hardhat/console.sol";

contract MinterMock is Ownable {
  Turf public turf;
  Farm public farm;

  constructor(address turf_, address farm_) {
    require(turf_.code.length > 0, "Not a contract");
    turf = Turf(turf_);
    require(farm_.code.length > 0, "Not a contract");
    farm = Farm(farm_);
  }

  function mintTurf(address to, uint256 amount) external onlyOwner {
    turf.mint(to, amount);
  }

  function mintFarm(address to, uint256 amount) external onlyOwner {
    farm.mint(to, amount);
  }
}
