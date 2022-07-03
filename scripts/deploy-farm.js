require('dotenv').config()
const hre = require("hardhat");
const ethers = hre.ethers

const DeployUtils = require('./lib/DeployUtils')
let deployUtils

async function main() {
  deployUtils = new DeployUtils(ethers)

  const chainId = await deployUtils.currentChainId()
  let [deployer] = await ethers.getSigners();

  const network = chainId === 56 ? 'bsc'
      : chainId === 97 ? 'bsc_testnet'
          : 'localhost'

  const { TOKEN_URI } = process.env
  if (!TOKEN_URI || !/\/$/.test(TOKEN_URI)) {
    console.error("Missing or invalid parameters")
    process.exit(1);
  }

  console.log(
      "Deploying contracts with the account:",
      deployer.address,
      'to', network
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  await deployUtils.deployProxy("FarmToken", TOKEN_URI)

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

