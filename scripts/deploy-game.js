require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const _ = require("lodash");

const DeployUtils = require("./lib/DeployUtils");
const turfConfJson = require("../test/fixtures/json/turfConf.json");
const turfSizeInfoJson = require("../test/fixtures/json/turfSizeConf.json");
const farmConfJson = require("../test/fixtures/json/farmConf.json");
const farmQualityLevelJson = require("../test/fixtures/json/farmQualityLevel.json");
const turfAttributesJson = require("../test/fixtures/json/turfAttributes.json");
const farmAttributesJson = require("../test/fixtures/json/farmAttributes.json");

let deployUtils;

let DOMINIC = "0x050639eD904074784b98aE4fAd904f3777962e75";
let VALIDATOR = "0xD5C44Da70b161335b121032F9e621B8F90A876D3";

let game;
let seed;
let bud;
let store;
let pool;
let gameViews;
let farm;
let turf;
let minter;

async function initStoreConf() {
  // basic turf configuration
  let confs = [];
  let cfgIds = [];
  for (let i = 0; i < turfConfJson.length; i++) {
    let conf = turfConfJson[i];
    let size = turfSizeInfoJson[i];
    cfgIds.push(conf.cfgId);
    confs.push(
      Object.assign(
        _.pick(conf, ["coordX", "coordY", "area", "width", "height", "buildingPermission"]),
        _.pick(size, ["stakeProfit", "farmStakeBonus"])
      )
    );
  }
  await deployUtils.Tx(store.batchInitTurfConf(cfgIds, confs), "Init TurfConf in store");

  // basic farm configuration
  confs = [];
  cfgIds = [];
  for (let i = 0; i < farmConfJson.length; i++) {
    let conf = farmConfJson[i];
    cfgIds.push(conf.cfgId);
    confs.push(
      _.pick(conf, [
        "productionType",
        "feature",
        "style",
        "billboard",
        "greenhouseAmount",
        "maxLevel",
        "area",
        "maxHP",
        "defenderAttributesBonus",
        "visual",
      ])
    );
  }
  await deployUtils.Tx(store.batchInitFarmConf(cfgIds, confs), "Init FarmConf in store");
}

async function initStoreInfo() {
  let confs = [];
  for (let i = 0; i < farmQualityLevelJson.length; i++) {
    let conf = farmQualityLevelJson[i];
    confs.push(
      _.pick(conf, [
        "cfgId",
        "quality",
        "level",
        "maxHPGrowth",
        "plantTimeReduction",
        "stakeProfit",
        "weedProductionGrowth",
        "defenderAttributesBonusGrowth",
        "upgradeCost",
        "repairCost",
        "storageGrowth",
        "claimableStorageGrowth",
      ])
    );
  }
  await deployUtils.Tx(store.batchInitFarmQualityLevel(confs), "Init FarmQualityLevel in store");
}

async function initAndDeploy() {
  store = await deployUtils.deployProxy("AttributesStore");
  await initStoreConf();
  // store = await deployUtils.attach("AttributesStore");

  seed = await deployUtils.attach("SeedToken");
  bud = await deployUtils.attach("BudToken");
  if (!seed) {
    seed = await deployUtils.deployProxy("SeedToken");
  }
  if (!bud) {
    bud = await deployUtils.deployProxy("BudToken");
  }

  // game = await deployUtils.attach("FarmOnTurfGame");
  game = await deployUtils.deployProxy("FarmOnTurfGame", seed.address, bud.address);
  await store.setFarmOnTurfGame(game.address);

  turf = await deployUtils.deployProxy("TurfToken", "https://meta.mob.land/turfs/");
  await deployUtils.Tx(turf.setMaxSupply(100), "Set max supply");

  await deployUtils.Tx(turf.setDefaultPlayer(game.address), "Set default player");

  await deployUtils.Tx(turf.setGame(game.address), "Set game for turf");
  // await turf.setApprovalForAll(game.address, true);

  farm = await deployUtils.deployProxy("FarmToken", "https://meta.mob.land/farms/");
  await deployUtils.Tx(farm.setMaxSupply(5000), "Set farm max supply");

  minter = await deployUtils.deploy("MinterMock", turf.address, farm.address);
  await deployUtils.Tx(turf.setFactory(minter.address, true), "Set factory for turf");

  await deployUtils.Tx(farm.setDefaultPlayer(game.address), "Set default player in farm");
  await deployUtils.Tx(farm.setFactory(minter.address, true), "Set factor for farm");

  await deployUtils.Tx(farm.setGame(game.address), "Set game in farm");

  await initStoreInfo();

  pool = await deployUtils.deployProxy("AssetsPool", turf.address, farm.address);
  await deployUtils.Tx(turf.setLocker(pool.address), "Set locker for turf");
  await deployUtils.Tx(farm.setLocker(pool.address), "Set locker for farm");
  gameViews = await deployUtils.deployProxy("GameViews", store.address, turf.address, farm.address, pool.address);
  await deployUtils.Tx(gameViews.setValidator(VALIDATOR), "Set validator in GameViews");
  await deployUtils.Tx(pool.setValidator(VALIDATOR), "Set validator in AssetsPool");

  await deployUtils.Tx(game.setStoreAndViews(store.address, gameViews.address), "Set store and views in game");
  await deployUtils.Tx(game.initTurfAndFarm(turf.address, farm.address), "Init turf and farm in game");
}

function randomUint32() {
  let d = Date.now() / 1000;
  return Math.round(d * Math.random());
}

function generateRandomFactors(maxId) {
  const factors = [];
  for (let i = 1; i <= maxId; i++) {
    factors.push({
      randomFactorOfSeedConsumption: randomUint32(),
      randomFactorOfWeedProduction: randomUint32(),
      randomFactorOfStorage: randomUint32(),
      randomFactorOfClaimableStorage: randomUint32(),
      randomFactorOfDefenderAttributesBonus: randomUint32(),
      randomFactorOfMaxHP: randomUint32(),
    });
  }
  return factors;
}

async function mintAndInitTokens() {
  // 49 turfs
  await deployUtils.Tx(minter.mintTurf(DOMINIC, 10), "Mint 10 turfs");
  await deployUtils.Tx(minter.mintTurf(DOMINIC, 10), "Mint 10 turfs");
  await deployUtils.Tx(minter.mintTurf(DOMINIC, 10), "Mint 10 turfs");
  await deployUtils.Tx(minter.mintTurf(DOMINIC, 10), "Mint 10 turfs");
  await deployUtils.Tx(minter.mintTurf(DOMINIC, 9), "Mint 9 turfs");

  let confs = [];
  let i = 1;
  for (let attr of turfAttributesJson) {
    confs.push(_.pick(attr, ["cfgId", "totalUsedArea", "location", "topography", "controller", "level"]));
    await deployUtils.Tx(turf.initAttributes(i, {level: attr.level}), "Init attributes");
    i++;
  }

  for (let i = 1; i < 50; i += 10) {
    let arr = [];
    for (let j = i; j < i + 10 && j < 50; j++) {
      arr.push(j);
    }
    await deployUtils.Tx(store.batchInitTurf(arr, confs.slice(i - 1, i + 9)), "Init turfs");
  }

  // 60 farms
  for (let i = 0; i < 3; i++) {
    await deployUtils.Tx(minter.mintFarm(DOMINIC, 20), "Mint 20 farms");
  }

  confs = [];
  i = 1;
  for (let attr of farmAttributesJson) {
    let conf = _.pick(attr, [
      "cfgId",
      "quality",
      "level",
      "turfTokenId",
      "currentHP",
      "farmState",
      "plantTime",
      "seedConsumption",
      "weedProduction",
      "maxStorage",
      "claimableStorage",
    ]);
    conf.weedStorage = 0;
    conf.turfTokenId = 0;
    confs.push(conf);
    await deployUtils.Tx(
      farm.initAttributes(
        i,
        {level: conf.level, farmState: conf.farmState, currentHP: conf.currentHP, weedReserves: 0},
        {gasLimit: 60000}
      ),
      "Init farm's confs"
    );
    i++;
    if (i > 60) {
      break;
    }
  }

  // TODO: we miss the random factors. Where are them?
  const randomFactors = generateRandomFactors(200);

  for (let i = 1; i < 61; i += 10) {
    let arr = [];
    for (let j = i; j < i + 10 && j < 61; j++) {
      arr.push(j);
    }
    await deployUtils.Tx(
      store.batchInitFarm(arr, confs.slice(i - 1, i + 9), randomFactors.slice(i - 1, i + 9), {gasLimit: 600000}),
      "Init farm's infos"
    );
  }

  // await expect(store.batchSetGreenhousesForFarm(3, [1, 0], [greenhouseConf]));
}

async function main() {
  deployUtils = new DeployUtils(ethers);
  require("./consoleLogAlert")();
  const chainId = await deployUtils.currentChainId();
  let [deployer] = await ethers.getSigners();

  const network = chainId === 56 ? "bsc" : chainId === 97 ? "bsc_testnet" : "localhost";

  console.log("Deploying contracts with the account:", deployer.address, "to", network);

  await initAndDeploy();
  await mintAndInitTokens();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
