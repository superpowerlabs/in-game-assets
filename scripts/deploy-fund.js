require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const path = require("path");
const fs = require("fs-extra");
const requireOrMock = require("require-or-mock");
const wallets = requireOrMock("scripts/wallets.json");
const DeployUtils = require("./lib/DeployUtils");
let deployUtils;

async function main() {
  deployUtils = new DeployUtils(ethers);
  require("./consoleLogAlert")();

  function pe(amount) {
    return ethers.utils.parseEther(amount.toString());
  }

  const chainId = await deployUtils.currentChainId();
  let [deployer] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 44787 ? "alfajores" : "localhost";

  console.log("Distributing assets on", network);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const wl = await deployUtils.attach("WhitelistSlot");
  const seed = await deployUtils.attach("SeedTokenMock");
  const busd = await deployUtils.attach("BUSDMock");
  let done = false;
  for (let name in wallets) {
    let wallet = wallets[name];
    if (wallet.funded) continue;
    console.log("Funding", name);
    let {address} = wallet;
    await deployUtils.Tx(wl.mintBatch(address, [1, 2], [5, 10]));
    await deployUtils.Tx(seed.mint(address, pe("10000000")));
    await deployUtils.Tx(busd.mint(address, pe("100000")));
    wallet.funded = true;
    done = true;
  }
  if (done) {
    await fs.writeFile(path.resolve(__dirname, "wallets.json"), JSON.stringify(wallets, null, 2));
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
