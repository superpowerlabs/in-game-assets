require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const DeployUtils = require("./lib/DeployUtils");
let deployUtils;

let VALIDATOR = "0xD5C44Da70b161335b121032F9e621B8F90A876D3";

async function main() {
  deployUtils = new DeployUtils(ethers);

  const chainId = await deployUtils.currentChainId();
  let [deployer] = await ethers.getSigners();

  const network =
    chainId === 56
      ? "bsc"
      : chainId === 5
      ? "goerli"
      : chainId === 97
      ? "bsc_testnet"
      : chainId === 43113
      ? "fuji"
      : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  // const farmToken = await deployUtils.attach("Farm");
  const farm = await deployUtils.attach("FarmMintable");
  // const seedToken = await deployUtils.deployProxy("SeedToken");

  // for (let address of [
  //   "0x81Edfbcc12Abb98A3660608Dd1B65105EF2F00E5",
  //   "0x34923658675B99B2DB634cB2BC0cA8d25EdEC743"
  // ]) {
  //   await deployUtils.Tx(
  //     seedToken.mint(address, ethers.utils.parseEther("1000000"), {gasLimit: 100000}),
  //     "Giving 1000000 SEED to " + address
  //   );
  //   // await budToken.mint(address, ethers.utils.parseEther("1000000"));
  // }
  await deployUtils.Tx(
    farm.batchMint(["0x81Edfbcc12Abb98A3660608Dd1B65105EF2F00E5", "0x34923658675B99B2DB634cB2BC0cA8d25EdEC743"], [2, 3]),
    "Minting farms"
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
