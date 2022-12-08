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
  let [deployer, whitelisted, whitelisted2, whitelisted3] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 43113 ? "fuji" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const turf = await deployUtils.deployProxy("Turf", "https://api.mob.land/meta/turfs/");
  const farm = await deployUtils.deployProxy("Farm", "https://api.mob.land/meta/farms/");

  const seed = await deployUtils.deployProxy("SeedTokenMock");
  await seed.mint(whitelisted.address, pe("10000000000"));
  await seed.mint(whitelisted2.address, pe("10000000000"));
  await seed.mint(whitelisted3.address, pe("10000000000"));

  const busd = await deployUtils.deployProxy("BUSDMock");
  await busd.mint(whitelisted.address, pe("10000000"));
  await busd.mint(whitelisted2.address, pe("10000000"));
  await busd.mint(whitelisted3.address, pe("10000000"));

  const factory = await deployUtils.deployProxy("NftFactory");
  await factory.setPaymentToken(seed.address, true);
  await factory.setPaymentToken(busd.address, true);

  const wl = await deployUtils.deploy("WhitelistSlot");
  await wl.setBurner(factory.address);
  for (let id = 1; id <= 2; id++) {
    let nft = id === 1 ? turf : farm;
    const amount = 5;
    await wl.mintBatch(whitelisted.address, [id], [amount], []);
    await wl.mintBatch(whitelisted2.address, [id], [amount], []);
    await wl.mintBatch(whitelisted3.address, [id], [amount], []);
    await nft.setFactory(factory.address, true);
    await factory.setNewNft(nft.address);
  }
  await turf.setMaxSupply(1000);
  await farm.setMaxSupply(3000);
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
