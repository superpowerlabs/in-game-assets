require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const DeployUtils = require("./lib/DeployUtils");
let deployUtils;

let VALIDATOR = "0xD5C44Da70b161335b121032F9e621B8F90A876D3";

async function main() {
  deployUtils = new DeployUtils(ethers);

  const chainId = await deployUtils.currentChainId();
  let [deployer] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 97 ? "bsc_testnet" : chainId === 43113 ? "fuji" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const farmToken = await deployUtils.attach("Farm");
  const turfToken = await deployUtils.attach("Turf");
  const seedToken = await deployUtils.attach("SeedToken");
  const budToken = await deployUtils.attach("BudToken");

  for (let address of [
    "0x3E4276Eb950C7a8aF7A1B4d03BDDF02e34A503f7",
    "0xB664130222198dBE922C20C912d9847Bd87E31b1",
    "0x5e7E3a602bBE9987BD653379bBA7Bf478D0570f5",
    "0x781e24d233758D949e161f944C3b577Ab49fe192",
  ]) {
    await deployUtils.Tx(
      seedToken.mint(address, ethers.utils.parseEther("1000000"), {gasLimit: 100000}),
      "Giving 1000000 SEED to " + address
    );
    // await budToken.mint(address, ethers.utils.parseEther("1000000"));
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
