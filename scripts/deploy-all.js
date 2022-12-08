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

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const turf = await deployUtils.deployProxy("Turf", "https://api.mob.land/meta/turfs/");
  const farm = await deployUtils.deployProxy("Farm", "https://api.mob.land/meta/farms/");

  const seed = chainId === 56 ? await deployUtils.attach("SeedToken") : await deployUtils.deployProxy("SeedTokenMock");
  const busd = chainId === 56 ? "0xe9e7cea3dedca5984780bafc599bd69add087d56" : await deployUtils.deployProxy("BUSDMock");

  const factory = await deployUtils.deployProxy("NftFactory");
  await factory.setPaymentToken(seed.address, true);
  await factory.setPaymentToken(busd.address, true);

  await turf.setMaxSupply(150);
  await farm.setMaxSupply(1250);

  await deployUtils.Tx(
    turf.mint(process.env.TURF_OWNER || deployer.address, 15, {gasLimit: 2000000}),
    "Minting turf 1-15 to " + (process.env.TURF_OWNER || deployer.address)
  );

  // const turf = await deployUtils.attach("Turf");
  // const farm = await deployUtils.attach("Farm");
  // const seed = await deployUtils.attach("SeedTokenMock");
  // const busd = await deployUtils.attach("BUSDMock");
  // const factory = await deployUtils.attach("NftFactory");

  const wl = await deployUtils.deploy("WhitelistSlot");
  await wl.setBurner(factory.address);
  await wl.setURI("https://api.mob.land/meta/wl");
  for (let id = 1; id <= 2; id++) {
    let nft = id === 1 ? turf : farm;
    await nft.setFactory(factory.address, true);
    await factory.setNewNft(nft.address);
  }

  await factory.setWl(wl.address);

  await wl.mintBatch(deployer.address, [1, 2], [10, 10]);

  const now = (await provider.getBlock()).timestamp;

  await deployUtils.Tx(
    factory.newSale(
      1,
      135,
      now,
      now + 3600 * 72,
      1,
      [busd.address, seed.address],
      [pe(419), pe(220500)],
      [pe(599), pe(295000)]
    ),
    "Setting sale for turf"
  );
  await deployUtils.Tx(
    factory.newSale(
      2,
      1250,
      now,
      now + 3600 * 72,
      2,
      [busd.address, seed.address],
      [pe(209), pe(110000)],
      [pe(299), pe(147500)]
    ),
    "Setting sale for farm"
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
