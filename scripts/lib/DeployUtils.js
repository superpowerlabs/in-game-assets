const path = require("path");
const fs = require("fs-extra");
const {Contract} = require("@ethersproject/contracts");
const abi = require("ethereumjs-abi");
const {deployProxyImpl} = require("@openzeppelin/hardhat-upgrades/dist/utils");

let deployedJson;

if (process.env.NODE_ENV === "test") {
  deployedJson = require("../../export/deployedForTest.json");
} else {
  deployedJson = require("../../export/deployed.json");
}

const oZChainName = {
  1: "mainnet",
  3: "ropsten",
  5: "goerli",
  56: "bsc",
};

const chainName = {
  1: "mainnet",
  3: "ropsten",
  5: "goerli",
  56: "bsc",
  97: "bsc_testnet",
  42: "kovan",
  1337: "localhost",
  31337: "hardhat",
  80001: "mumbai",
  41224: "avalance",
  43113: "fuji",
};

const scanner = {
  1337: "localhost",
  1: "etherscan.io",
  3: "ropsten.etherscan.io",
  5: "goerli.etherscan.io",
  56: "bscscan.com",
  97: "testnet.bscscan.com",
  41224: "snowtrace.io",
  43113: "testnet.snowtrace.io",
};

class DeployUtils {
  constructor(ethers) {
    this.ethers = ethers;
  }

  async sleep(millis) {
    // eslint-disable-next-line no-undef
    return new Promise((resolve) => setTimeout(resolve, millis));
  }

  getProviders() {
    const {INFURA_API_KEY} = process.env;

    const rpc = (url) => {
      return new this.ethers.providers.JsonRpcProvider(url);
    };

    let providers = {
      1337: this.ethers.getDefaultProvider("http://localhost:8545"),
    };

    if (INFURA_API_KEY) {
      providers = Object.assign(providers, {
        1: rpc(`https://mainnet.infura.io/v3/${INFURA_API_KEY}`),
        3: rpc(`https://ropsten.infura.io/v3/${INFURA_API_KEY}`),
        4: rpc(`https://rinkeby.infura.io/v3/${INFURA_API_KEY}`),
        5: rpc(`https://goerli.infura.io/v3/${INFURA_API_KEY}`),
      });
    }

    return providers;
  }

  async getABI(name, folder) {
    const fn = path.resolve(__dirname, `../../artifacts/contracts/${folder}/${name}.sol/${name}.json`);
    if (fs.pathExists(fn)) {
      return JSON.parse(await fs.readFile(fn, "utf8")).abi;
    }
  }

  async getContract(name, folder, address, chainId) {
    return new Contract(address, await this.getABI(name, folder), this.getProviders()[chainId]);
  }

  async Tx(promise, msg) {
    if (msg) {
      console.debug(msg);
    }
    let tx = await promise;
    console.log("Tx:", tx.hash);
    await tx.wait();
    console.log("Mined.");
  }

  async deploy(contractName, ...args) {
    const chainId = await this.currentChainId();
    console.debug("Deploying", contractName, "to", this.network(chainId));
    const contract = await ethers.getContractFactory(contractName);
    const deployed = await contract.deploy(...args);
    console.debug("Tx:", deployed.deployTransaction.hash);
    await deployed.deployed();
    console.debug("Deployed at", deployed.address);
    await this.saveDeployed(chainId, [contractName], [deployed.address]);
    console.debug(`To verify the source code:
    
  npx hardhat verify --show-stack-traces --network ${this.network(chainId)} ${deployed.address} ${[...args]
        .map((e) => e.toString())
        .join(" ")}
      
`);
    return deployed;
  }

  async attach(contractName) {
    const chainId = await this.currentChainId();
    const contract = await ethers.getContractFactory(contractName);
    return contract.attach(deployedJson[chainId][contractName]);
  }

  async deployProxy(contractName, ...args) {
    const chainId = await this.currentChainId();
    console.debug("Deploying", contractName, "to", this.network(chainId));
    const contract = await ethers.getContractFactory(contractName);
    const deployed = await upgrades.deployProxy(contract, [...args]);
    console.debug("Tx:", deployed.deployTransaction.hash);
    await deployed.deployed();
    console.debug("Deployed at", deployed.address);
    await this.saveDeployed(chainId, [contractName], [deployed.address]);
    console.debug(await this.verifyCodeInstructions(contractName, deployed.deployTransaction.hash));
    return deployed;
  }

  async upgradeProxy(contractName, gasLimit) {
    const chainId = await this.currentChainId();
    console.debug("Upgrading", contractName, "to", this.network(chainId));
    const Contract = await ethers.getContractFactory(contractName);
    const upgraded = await upgrades.upgradeProxy(deployedJson[chainId][contractName], Contract, gasLimit ? {gasLimit} : {});
    console.debug("Tx:", upgraded.deployTransaction.hash);
    await upgraded.deployed();
    console.debug("Upgraded");
    console.debug(await this.verifyCodeInstructions(contractName, upgraded.deployTransaction.hash));
    return upgraded;
  }

  network(chainId) {
    return chainName[chainId];
  }

  async currentChainId() {
    return (await this.ethers.provider.getNetwork()).chainId;
  }

  async saveDeployed(chainId, names, addresses, extras) {
    if (names.length !== addresses.length) {
      throw new Error("Inconsistent arrays");
    }

    const deployedFilename = process.env.NODE_ENV === "test" ? "deployedForTest" : "deployed";

    const deployedJson = path.resolve(__dirname, `../../export/${deployedFilename}.json`);
    if (!(await fs.pathExists(deployedJson))) {
      await fs.ensureDir(path.dirname(deployedJson));
      await fs.writeFile(deployedJson, "{}");
    }
    const deployed = JSON.parse(await fs.readFile(deployedJson, "utf8"));
    if (!deployed[chainId]) {
      deployed[chainId] = {};
    }
    const data = {};
    for (let i = 0; i < names.length; i++) {
      data[names[i]] = addresses[i];
    }
    deployed[chainId] = Object.assign(deployed[chainId], data);

    if (extras) {
      // data needed for verifications
      if (!deployed.extras) {
        deployed.extras = {};
      }
      if (!deployed.extras[chainId]) {
        deployed.extras[chainId] = {};
      }
      deployed.extras[chainId] = Object.assign(deployed.extras[chainId], extras);
    }
    // console.log(deployed)
    await fs.writeFile(deployedJson, JSON.stringify(deployed, null, 2));
  }

  encodeArguments(parameterTypes, parameterValues) {
    return abi.rawEncode(parameterTypes, parameterValues).toString("hex");
  }

  async verifyCodeInstructions(contractName, tx) {
    const chainId = await this.currentChainId();
    let chainName = oZChainName[chainId] || "unknown-" + chainId;
    const oz = JSON.parse(await fs.readFile(path.resolve(__dirname, "../../.openzeppelin", chainName + ".json")));
    let address;
    let keys = Object.keys(oz.impls);
    let i = keys.length - 1;
    LOOP: while (i >= 0) {
      let key = keys[i];
      let storage = oz.impls[key].layout.storage;
      for (let s of storage) {
        if (s.contract === contractName) {
          address = oz.impls[key].address;
          break LOOP;
        }
      }
      i--;
    }

    let response = `To verify ${contractName} source code, flatten the source code and find the address of the implementation looking at the data in the following transaction 
    
https://${scanner[chainId]}/tx/${tx}

as a single file, without constructor's parameters    

`;
    return this.saveLog(contractName, response);
  }

  async saveLog(contractName, response) {
    const chainId = await this.currentChainId();
    const logDir = path.resolve(__dirname, "../../log");
    await fs.ensureDir(logDir);
    const shortDate = new Date().toISOString().substring(5, 16);
    const fn = [contractName, chainId, shortDate].join("_") + ".log";
    if (chainId !== 1337) {
      await fs.writeFile(path.resolve(logDir, fn), response);
      return `${response}
    
Info saved in:
    
    log/${fn}
`;
    } else {
      return response;
    }
  }
}

module.exports = DeployUtils;
