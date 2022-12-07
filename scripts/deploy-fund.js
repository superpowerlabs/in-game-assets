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

  let wallets = [
    // "0x5e7E3a602bBE9987BD653379bBA7Bf478D0570f5",
    // "0xa91148A563606aAD1c70104E1DA82FEC4d0B8A9F",
    // "0x3E4276Eb950C7a8aF7A1B4d03BDDF02e34A503f7",
  ];

  const chainId = await deployUtils.currentChainId();
  let [deployer] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 44787 ? "alfajores" : "localhost";

  console.log("Distributing assets on", network);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const wl = await deployUtils.attach("WhitelistSlot");
  const seed = await deployUtils.attach("SeedTokenMock");
  const busd = await deployUtils.attach("BUSDMock");
  for (let address of wallets) {
    await deployUtils.Tx(wl.mintBatch(address, [1, 2], [5, 10]));
    await deployUtils.Tx(seed.mint(address, pe("10000000")));
    await deployUtils.Tx(busd.mint(address, pe("100000")));
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
