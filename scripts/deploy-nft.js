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

  const recipients = {
    // Zhimin: "0x4ec0655C4A6db5A0515bCF111C7202b845fd329D",
    // Zhimin2: "0x4ec0655C4A6db5A0515bCF111C7202b845fd329D",
    // Zhimin3: "0x4ec0655C4A6db5A0515bCF111C7202b845fd329D",
    // Zhimin4: "0x4ec0655C4A6db5A0515bCF111C7202b845fd329D",
    // Stella: "0x3E4276Eb950C7a8aF7A1B4d03BDDF02e34A503f7",
    // Tim: "0xB664130222198dBE922C20C912d9847Bd87E31b1",
    // Dev1: "0x5e7E3a602bBE9987BD653379bBA7Bf478D0570f5",
    // Dev2: "0x781e24d233758D949e161f944C3b577Ab49fe192",
    // Devansh: "0x5e7E3a602bBE9987BD653379bBA7Bf478D0570f5",
    Rolando: "0x8A96e7F2cae379559496C810e9B7DecE971B771E",
    Jerry: "0xa27E8ACBF87979A7A25480c428B9fe8A56a3Fc85",
    Yacin: "0x11b896e896026de7976c209bbac7e60a6b5f846a",
  };

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
