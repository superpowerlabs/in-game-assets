require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");
const {factory} = require("typescript");

const DeployUtils = require("./lib/DeployUtils");
let deployUtils;

async function main() {
  deployUtils = new DeployUtils(ethers);

  function pe(amount) {
    return ethers.utils.parseEther(amount.toString());
  }

  const chainId = await deployUtils.currentChainId();
  let [deployer, whitelisted, whitelisted2, whitelisted3] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 43113 ? "fuji" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const turf = await deployUtils.deployProxy("Turf", "https://api.mob.land/meta/turfs/");
  const farm = await deployUtils.deployProxy("Farm", "https://api.mob.land/meta/farms/");

  const seed = chainId === 56 ? await deployUtils.attach("SeedToken") : await deployUtils.deployProxy("SeedTokenMock");
  const busd = chainId === 56 ? "0xe9e7cea3dedca5984780bafc599bd69add087d56" : await deployUtils.deployProxy("BUSDMock");

  const factory = await deployUtils.deployProxy("NftFactory");
  await factory.setPaymentToken(seed.address, true);
  await factory.setPaymentToken(busd.address, true);

  const wl = await deployUtils.deploy("WhitelistSlot", factory.address);
  await wl.setURI("https://api.mob.land/meta/wl");

  await turf.setMaxSupply(150);
  await farm.setMaxSupply(1250);

  await factory.setPrice(1, busd.address, pe(419), pe(599));
  await factory.setPrice(1, seed.address, pe(220500), pe(295000));
  await factory.setPrice(2, busd.address, pe(209), pe(299));
  await factory.setPrice(2, seed.address, pe(110000), pe(147500));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
