require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");
const _ = require("lodash");

const DeployUtils = require("./lib/DeployUtils");
let deployUtils;

const farmAttributesJson = require("./lib/farmAttributes.json");
const turfAttributesJson = require("./lib/turfAttributes.json");

async function main() {
  deployUtils = new DeployUtils(ethers);

  const chainId = await deployUtils.currentChainId();
  let [deployer, whitelisted] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 43113 ? "fuji" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const token = await deployUtils.deployProxy("CharacterToken", "https://data.mob.land/genesis_blueprints/json/");
  await deployUtils.Tx(token.mint("0x050639eD904074784b98aE4fAd904f3777962e75", 20), "20 tokens");
  await deployUtils.Tx(token.mint("0x050639eD904074784b98aE4fAd904f3777962e75", 20), "20 tokens");
  await deployUtils.Tx(token.mint("0x050639eD904074784b98aE4fAd904f3777962e75", 20), "20 tokens");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
