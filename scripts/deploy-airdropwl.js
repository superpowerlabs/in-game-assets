require("dotenv").config();
const path = require("path");
const fs = require("fs-extra");
const hre = require("hardhat");
const ethers = hre.ethers;
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");
const {wl: turfWl} = require("./data/wlTurfWinners.json");
const {wl: farmWl} = require("./data/wlFarmWinners.json");

const DeployUtils = require("./lib/DeployUtils");
let deployUtils;

async function main() {
  deployUtils = new DeployUtils(ethers);
  require("./consoleLogAlert")();

  const chainId = await deployUtils.currentChainId();
  let [deployer] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 44787 ? "alfajores" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const wl = await deployUtils.attach("WhitelistSlot");

  async function airdrop(list, wlId) {
    let i = 0;
    let wallets = [];
    let ids = [];
    let amounts = [];
    for (let wallet of list) {
      if (chainId === 56 && wallet[2]) {
        continue;
      }
      wallets.push(wallet[0]);
      ids.push([wlId]);
      amounts.push([wallet[1]]);
      wallet[2] = true;
      i++;
      if (i === 10) {
        await deployUtils.Tx(
          wl.mintMany(
            wallets,
            ids,
            amounts,
            chainId !== 1337
              ? {
                  gasLimit: 400000,
                }
              : {}
          ),
          "Airdropping " + +wallets.length + " wl for " + (wlId === 1 ? "turf" : "farm") + " to \n" + wallets.join("\n") + "\n"
        );
        if (chainId === 56) {
          await fs.writeFile(
            path.resolve(__dirname, "data/wl" + (wlId ? "Turf" : "Farm") + "Winners.json"),
            JSON.stringify(list)
          );
        }
        i = 0;
        wallets = [];
        ids = [];
        amounts = [];
      }
    }
    if (wallets.length > 0) {
      await deployUtils.Tx(
        wl.mintMany(wallets, ids, amounts, {
          gasLimit: 750000,
        }),
        "Airdropping " + +wallets.length + " wl for " + (wlId === 1 ? "turf" : "farm") + " to \n" + wallets.join("\n") + "\n"
      );
      if (chainId === 56) {
        await fs.writeFile(
          path.resolve(__dirname, "data/wl" + (wlId ? "Turf" : "Farm") + "Winners.json"),
          JSON.stringify(list)
        );
      }
    }
  }

  await wl.mintBatch("0xA32912c58298f49a99B9eA3084721056F5d22FF1", [1, 2], [4, 4]);

  // await airdrop(turfWl, 1);
  // await airdrop(farmWl, 2);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
