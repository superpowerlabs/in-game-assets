require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");
const {factory} = require("typescript");

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
  const provider = this.ethers.provider;

  const network = chainId === 56 ? "bsc" : chainId === 44787 ? "alfajores" : "localhost";

  console.log("Setting the sale with the account:", deployer.address, "to", network);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const seed = chainId === 56 ? await deployUtils.attach("SeedToken") : await deployUtils.deployProxy("SeedTokenMock");
  const busd =
    chainId === 56
      ? {address: "0xe9e7cea3dedca5984780bafc599bd69add087d56"}
      : // : await deployUtils.deployProxy("BUSDMock");
        await deployUtils.attach("BUSDMock");

  const factory = await deployUtils.attach("NftFactory");

  // 2022-12-14T17:30:00.000Z
  const startAt = 1671039000;
  const wlEndAt = startAt + 3600 * 24 * 5;

  await deployUtils.Tx(
    factory.newSale(1, 135, startAt, wlEndAt, 1, [busd.address, seed.address], [pe(420), pe(220500)], [pe(599), pe(295000)]),
    "Setting sale for turf"
  );
  await deployUtils.Tx(
    factory.newSale(2, 1250, startAt, wlEndAt, 2, [busd.address, seed.address], [pe(215), pe(110000)], [pe(299), pe(147500)]),
    "Setting sale for farm"
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
