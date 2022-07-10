require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");

const DeployUtils = require("./lib/DeployUtils");
let deployUtils;

async function main() {
  deployUtils = new DeployUtils(ethers);

  const chainId = await deployUtils.currentChainId();
  let [deployer, whitelisted] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 43113 ? "fuji" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const turf = await deployUtils.deployProxy("TurfToken", "https://meta.mob.land/turfs/");
  const farm = await deployUtils.deployProxy("FarmToken", "https://meta.mob.land/farms/");
  // const turf = await deployUtils.attach("TurfToken")
  // const farm = await deployUtils.attach("FarmToken")
  const wl = await deployUtils.deploy("WhitelistSlot");
  const factory = await deployUtils.deployProxy("NftFactory");

  for (let id = 2; id <= 2; id++) {
    let nft = id === 1 ? turf : farm;
    const amount = 5;
    // await wl.mintBatch(whitelisted.address, [id], [amount], []);
    // await wl.setBurnerForID(nft.address, id);
    await deployUtils.Tx(nft.setFactory(factory.address, true), "setFactory");
    await deployUtils.Tx(nft.setMaxSupply(1000), "setMaxSupply");
    await deployUtils.Tx(
      nft.setWhitelist(
        wl.address,
        getCurrentTimestamp() // + 3600 * 24 // 1 day
      ),
      "setWhiteList"
    );
    await deployUtils.Tx(factory.setNewNft(nft.address), "setNewNft");
    await deployUtils.Tx(factory.setPrice(id, ethers.utils.parseEther("0.001")), "setPrice");
  }

  // console.log(whitelisted.address)
  // return

  // for (let id = 1; id <= 2; id++) {
  //   let nft = id === 1 ? turf : farm;
  //   const amount = 5;
  //
  //   await deployUtils.Tx(factory.connect(deployer).buyTokens(id, amount, {
  //     value: ethers.BigNumber.from(await factory.getPrice(id)).mul(amount),
  //   }), "buyTokens");
  // }

  // for (let id = 1; id <= 20; id++) {
  //   let nft = farm
  //   await deployUtils.Tx(nft.connect(deployer)["safeTransferFrom(address,address,uint256)"](deployer.address,"0x050639eD904074784b98aE4fAd904f3777962e75", id), "transfer "+ id);
  // }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
