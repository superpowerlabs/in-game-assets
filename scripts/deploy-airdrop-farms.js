require("dotenv").config();
const path = require("path");
const fs = require("fs-extra");
const hre = require("hardhat");
const ethers = hre.ethers;
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");
const farmWinners = require("./data/freeFarmWinners.json");

const DeployUtils = require("./lib/DeployUtils");

async function main() {
  let deployUtils = new DeployUtils(ethers);
  // require("./consoleLogAlert")();

  const chainId = await deployUtils.currentChainId();
  let [deployer] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 44787 ? "alfajores" : chainId === 43113 ? "fuji" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const farm = await deployUtils.attach("Farm");
  const factory = await deployUtils.attach("NftFactory");

  if (await farm.hasFactories()) {
    await farm.setFactory(factory.address, false);
  }

  for (let i = farmWinners.length - 1; i >= 0; i--) {
    const {wallet, quantity, done} = farmWinners[i];
    if (chainId !== 56 || !done) {
      await deployUtils.Tx(
        farm.mint(wallet, quantity, {
          gasLimit: 100000 + 130000 * quantity,
        }),
        "Minting " + quantity + " free farms to " + wallet
      );
      if (chainId === 56) {
        farmWinners[i].done = true;
        await fs.writeFile(path.resolve(__dirname, "data/freeFarmWinners.json"), JSON.stringify(farmWinners));
      }
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
