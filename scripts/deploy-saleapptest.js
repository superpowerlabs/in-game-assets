require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");
const {factory} = require("typescript");

const DeployUtils = require("./lib/DeployUtils");
let deployUtils;

async function main() {
  const eth_amount = ethers.utils.parseEther("10000000000");
  deployUtils = new DeployUtils(ethers);

  const chainId = await deployUtils.currentChainId();
  let [deployer, whitelisted, whitelisted2, whitelisted3] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 97 ? "bsc_testnet" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const turf = await deployUtils.deployProxy("Turf", "https://api.mob.land/meta/turfs/");
  const farm = await deployUtils.deployProxy("Farm", "https://api.mob.land/meta/farms/");
  const wl = await deployUtils.deploy("WhitelistSlot");

  const seed = await deployUtils.deployProxy("SeedTokenMock");
  await seed.mint(whitelisted.address, eth_amount);
  await seed.mint(whitelisted2.address, eth_amount);
  await seed.mint(whitelisted3.address, eth_amount);

  const factory = await deployUtils.deployProxy("NftFactory", seed.address);

  for (let id = 1; id <= 2; id++) {
    let nft = id === 1 ? turf : farm;
    const amount = 5;
    await wl.mintBatch(whitelisted.address, [id], [amount], []);
    await wl.mintBatch(whitelisted2.address, [id], [amount], []);
    await wl.mintBatch(whitelisted3.address, [id], [amount], []);
    await wl.setBurnerForID(nft.address, id);
    await nft.setWhitelist(
      wl.address,
      getCurrentTimestamp() + 3600 * 24 // 1 day
    );
    await nft.setFactory(factory.address, true);
    await factory.setNewNft(nft.address);
  }
  await turf.setMaxSupply(1000);
  await farm.setMaxSupply(3000);
  await factory.setPrice(1, ethers.utils.parseEther("0.01"));
  await factory.setPriceInSeed(1, ethers.utils.parseEther("100"));
  await factory.setPrice(2, ethers.utils.parseEther("0.05"));
  await factory.setPriceInSeed(2, ethers.utils.parseEther("500"));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
