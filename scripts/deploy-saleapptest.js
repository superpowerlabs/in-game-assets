require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");

const DeployUtils = require("./lib/DeployUtils");
let deployUtils;

async function main() {
  deployUtils = new DeployUtils(ethers);

  const chainId = await deployUtils.currentChainId();
  let [deployer, whitelisted, whitelisted2, whitelisted3] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 97 ? "bsc_testnet" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const SuperpowerNFT = await ethers.getContractFactory("SuperpowerNFT");
  const turf = await upgrades.deployProxy(SuperpowerNFT, ["Mobland Turf", "MLT", "https://data.mob.land/turf/"]);
  // Wait one at time because if an error occurs, you can restart from there, if you run before all the transaction, than only later you wait for the transaction to be included in a block, it becomes a mess to try to restart the script from where you left. Keeping them in order, you can comment the already executed code, attach the previous addresses, if needed, and execute the rest.
  await turf.deployed();
  await deployUtils.saveDeployed(chainId, [`TurfToken|SuperpowerNFT`], [turf.address]);
  console.log("TurfToken deployed to:", turf.address);

  const farm = await upgrades.deployProxy(SuperpowerNFT, ["Mobland Farm", "MLF", "https://data.mob.land/farm/"]);
  await farm.deployed();
  await deployUtils.saveDeployed(chainId, [`FarmToken|SuperpowerNFT`], [farm.address]);
  console.log("FarmToken deployed to:", farm.address);

  const Whitelist = await ethers.getContractFactory("WhitelistSlot");
  const wl = await Whitelist.deploy();
  await wl.deployed();
  await deployUtils.saveDeployed(chainId, [`WhitelistSlot`], [wl.address]);
  console.log("WhitelistSlot deployed at ", whitelisted.address);

  const NftFactory = await ethers.getContractFactory("NftFactory");
  const nftFarm = await upgrades.deployProxy(NftFactory, []);
  await nftFarm.deployed();
  await deployUtils.saveDeployed(chainId, [`NftFactory`], [nftFarm.address]);
  console.log("NftFactory deployed to:", nftFarm.address);

  const Game = await ethers.getContractFactory("PlayerMockUpgradeable");
  const game = await upgrades.deployProxy(Game, []);
  await game.deployed();
  console.log("PlayerMockUpgradeable deployed to:", game.address);

  for (let id = 1; id <= 2; id++) {
    let nft = id === 1 ? turf : farm;
    const amount = 5;
    await wl.mintBatch(whitelisted.address, [id], [amount], []);
    await wl.mintBatch(whitelisted2.address, [id], [amount], []);
    await wl.mintBatch(whitelisted3.address, [id], [amount], []);
    await wl.setBurnerForID(nft.address, id);
    await turf.setWhitelist(
      wl.address,
      getCurrentTimestamp() + 3600 * 24 // 1 day
    );
    await nft.setFarmer(nftFarm.address, true);
    await nftFarm.setNewNft(nft.address);
    await nftFarm.setPrice(id, ethers.utils.parseEther("0.01"));
    await nft.setMaxSupply(1000);
    await nft.setDefaultPlayer(game.address);
  }

  // await nftFarm.connect(whitelisted).buyTokens(1, 2, {
  //   value: ethers.BigNumber.from((await nftFarm.getPrice(1)).mul(2)),
  // })
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
