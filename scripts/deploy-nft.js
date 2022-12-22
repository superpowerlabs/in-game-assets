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

  const farm = await deployUtils.deployProxy("Farm", "https://meta.mob.land/farm/");

  await turf.setMaxSupply(600);
  await farm.setMaxSupply(5000);

  const turfAuctioner = chainId === 56 ? process.env.TURF_OWNER : deployer.address;

  await deployUtils.Tx(turf.mint(turfAuctioner, 15, {gasLimit: 2000000}), "Minting turf 1-15 to " + turfAuctioner);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });