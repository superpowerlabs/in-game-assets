require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const DeployUtils = require("./lib/DeployUtils");
let deployUtils;

let VALIDATOR = "0xD5C44Da70b161335b121032F9e621B8F90A876D3";

async function main() {
  deployUtils = new DeployUtils(ethers);
  require("./consoleLogAlert")();
  const chainId = await deployUtils.currentChainId();
  let [deployer] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 97 ? "bsc_testnet" : chainId === 43113 ? "fuji" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const farmToken = await deployUtils.attach("Farm");
  const turfToken = await deployUtils.attach("Turf");
  const seedToken = await deployUtils.attach("SeedToken" + (chainId !== 56 ? "Mock" : ""));
  const budToken = await deployUtils.attach("BudToken" + (chainId !== 56 ? "Mock" : ""));

  const gamePool = await deployUtils.deployProxy(
    "GamePool",
    turfToken.address,
    farmToken.address,
    seedToken.address,
    budToken.address
  );

  console.log("To verify GamePool flatten the code and submit it for the implementation");

  await deployUtils.saveDeployed(chainId, ["GameToken"], [gamePool.address]);

  await deployUtils.Tx(turfToken.setGame(gamePool.address), "set game in turf");
  await deployUtils.Tx(turfToken.setDefaultPlayer(gamePool.address), "set default player in turf");
  await deployUtils.Tx(turfToken.setLocker(gamePool.address), "set locker in turf");

  await deployUtils.Tx(farmToken.setGame(gamePool.address), "set game in farm");
  await deployUtils.Tx(farmToken.setDefaultPlayer(gamePool.address), "set default player in farm");
  await deployUtils.Tx(farmToken.setLocker(gamePool.address), "set locker in farm");

  await deployUtils.Tx(gamePool.setValidator(0, VALIDATOR), "set validator in pool");
  await deployUtils.Tx(gamePool.setValidator(1, VALIDATOR), "set validator in pool");

  await deployUtils.Tx(budToken.unpauseAllowance(), "unpause allowance in bud token");
  await deployUtils.Tx(budToken.setMinter(gamePool.address, true), "set the pool as minter of bud tokens");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
