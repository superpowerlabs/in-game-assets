require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");
const _ = require("lodash");

const DeployUtils = require("./lib/DeployUtils");
let deployUtils;

const farmAttributesJson = require("./lib/farmAttributes.json");
const turfAttributesJson = require("./lib/turfAttributes.json");

async function main() {
  deployUtils = new DeployUtils(ethers);

  const chainId = await deployUtils.currentChainId();
  let [deployer, whitelisted] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 43113 ? "fuji" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  // const turf = await deployUtils.deployProxy("TurfToken", "https://meta.mob.land/turfs/");
  // const farm = await deployUtils.deployProxy("FarmToken", "https://meta.mob.land/farms/");
  const turf = await deployUtils.attach("TurfToken");
  const farm = await deployUtils.attach("FarmToken");
  const wl = await deployUtils.attach("WhitelistSlot");
  const factory = await deployUtils.attach("NftFactory");

  // for (let id = 1; id <= 2; id++) {
  //   let nft = id === 1 ? turf : farm;
  //   const amount = 5;
  //   // await wl.mintBatch(whitelisted.address, [id], [amount], []);
  //   // await wl.setBurnerForID(nft.address, id);
  //   await deployUtils.Tx(nft.setFactory(factory.address, true), "setFactory");
  //   await deployUtils.Tx(nft.setMaxSupply(1000), "setMaxSupply");
  //   await deployUtils.Tx(
  //     nft.setWhitelist(
  //       wl.address,
  //       getCurrentTimestamp() // + 3600 * 24 // 1 day
  //     ),
  //     "setWhiteList"
  //   );
  //   await deployUtils.Tx(factory.setNewNft(nft.address), "setNewNft");
  //   await deployUtils.Tx(factory.setPrice(id, ethers.utils.parseEther("0.0001")), "setPrice");
  // }
  //
  // let id = 1
  // let price = await factory.getPrice(id)
  //
  async function buy(what = "farm") {
    await deployUtils.Tx(
      factory.connect(deployer).buyTokens(id, amount, {
        value: price.mul(amount),
      }),
      "buyTokens " + what
    );
  }
  //
  // let amount = 10
  // await buy("turf")
  // await buy("turf")
  // await buy("turf")
  // await buy("turf")
  // amount = 9
  // await buy("turf")

  let confs = [];

  // await deployUtils.Tx(turf.connect(deployer)["safeTransferFrom(address,address,uint256)"](deployer.address,"0x050639eD904074784b98aE4fAd904f3777962e75", 9, {gasLimit: 120000}), "transfer "+ 9);

  let i = 10;

  // for (let attr of turfAttributesJson) {
  //   await deployUtils.Tx(turf.initAttributes(i, {level: attr.level}), "Setting level");
  //   await deployUtils.Tx(turf.connect(deployer)["safeTransferFrom(address,address,uint256)"](deployer.address,"0x050639eD904074784b98aE4fAd904f3777962e75", i, {gasLimit: 120000}), "transfer "+ i);
  //   i++;
  //   if (i > 20) {
  //     break
  //   }
  // }

  id = 2;
  price = await factory.getPrice(id);

  amount = 20;
  for (let i = 0; i < 3; i++) {
    await buy();
  }

  confs = [];
  i = 1;
  for (let attr of farmAttributesJson) {
    let conf = _.pick(attr, ["level", "currentHP", "farmState"]);
    conf.turfTokenId = 0;
    confs.push(conf);
    await deployUtils.Tx(
      farm.initAttributes(i, {level: conf.level, farmState: conf.farmState, currentHP: conf.currentHP, weedReserves: 0}),
      "Set attributes for farm"
    );
    await deployUtils.Tx(
      farm
        .connect(deployer)
        ["safeTransferFrom(address,address,uint256)"](deployer.address, "0x050639eD904074784b98aE4fAd904f3777962e75", i, {
          gasLimit: 120000,
        }),
      "transfer " + i
    );
    i++;
    if (i > 60) {
      break;
    }
  }

  console.log("Configuration ready");

  // console.log(whitelisted.address)
  // return
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
