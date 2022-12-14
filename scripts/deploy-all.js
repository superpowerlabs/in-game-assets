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

  const chainId = await deployUtils.currentChainId();
  let [deployer] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 44787 ? "alfajores" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const turf = await deployUtils.deployProxy("Turf", "https://meta.mob.land/turf/");
  const farm = await deployUtils.deployProxy("Farm", "https://meta.mob.land/farm/");

  const seed = chainId === 56 ? await deployUtils.attach("SeedToken") : await deployUtils.deployProxy("SeedTokenMock");
  const busd =
    chainId === 56 ? {address: "0xe9e7cea3dedca5984780bafc599bd69add087d56"} : await deployUtils.deployProxy("BUSDMock");
  // : await deployUtils.attach("BUSDMock");

  const factory = await deployUtils.deployProxy("NftFactory");
  await factory.setPaymentToken(seed.address, true);
  await factory.setPaymentToken(busd.address, true);

  await turf.setMaxSupply(150);
  await farm.setMaxSupply(1250);

  await deployUtils.Tx(
    turf.mint(process.env.TURF_OWNER, 15, {gasLimit: 2000000}),
    "Minting turf 1-15 to " + process.env.TURF_OWNER
  );

  // const turf = await deployUtils.attach("Turf");
  // const farm = await deployUtils.attach("Farm");
  // const seed = await deployUtils.attach("SeedTokenMock");
  // const busd = await deployUtils.attach("BUSDMock");
  // const factory = await deployUtils.attach("NftFactory");

  // const wl = await deployUtils.deploy("WhitelistSlot");
  const wl = await deployUtils.attach("WhitelistSlot");
  await deployUtils.Tx(wl.setBurner(factory.address), "Set burner in WL");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
