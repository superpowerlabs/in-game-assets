require("dotenv").config();
const path = require("path");
const fs = require("fs-extra");
const hre = require("hardhat");
const ethers = hre.ethers;
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");
const {factory} = require("typescript");

const DeployUtils = require("./lib/DeployUtils");
let deployUtils;

async function main() {
  deployUtils = new DeployUtils(ethers);
  require("./consoleLogAlert")();

  const chainId = await deployUtils.currentChainId();
  let [deployer] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 44787 ? "alfajores" : chainId === 43113 ? "fuji" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const turf = await deployUtils.attach("Turf", "https://meta.mob.land/turf/");
  const farm = await deployUtils.attach("Farm", "https://meta.mob.land/farm/");

  // await turf.setMaxSupply(600);
  // await farm.setMaxSupply(5000);

  const recipients = {};

  for (let user in recipients) {
    const address = recipients[user];
    await deployUtils.Tx(turf.mint(address, 10, {gasLimit: 2000000}), "Minting turfs to " + address);
    await deployUtils.Tx(farm.mint(address, 30, {gasLimit: 4000000}), "Minting farms to " + address);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
