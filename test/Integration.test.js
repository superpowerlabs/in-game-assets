process.env.NODE_ENV = "test";
const path = require("path");
const fs = require("fs-extra");
const {expect, assert} = require("chai");
const _ = require("lodash");

const {
  initEthers,
  signPackedData,
  cleanStruct,
  randomNonce,
  getTimestamp,
  overrideConsoleLog,
  restoreConsoleLog,
} = require("./helpers");

// Perform your tests
// ...

// Restore the original console.log function
// console.log = console.log.bind(console);

const DeployUtils = require("../scripts/lib/DeployUtils");

describe("Integration test", function () {
  let owner, holder, renter;
  let farm, turf, validator0, validator1;
  let seed;
  let bud;
  let pool;
  let minter, buyer1, buyer2, buyer3, buyer4, buyer5;
  const turfTokenType = 1;
  const farmTokenType = 2;
  const wrongTokenType = 4;

  const tempDir = path.resolve(__dirname, "../tmp/test");
  let turfAttributesJson;
  let farmAttributesJson;

  const deployUtils = new DeployUtils(ethers);

  let validator0PK = "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a";
  let validator1PK = "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba";

  before(async function () {
    [owner, holder, renter, buyer1, validator0, validator1, buyer2, buyer3, buyer4, buyer5] = await ethers.getSigners();
    initEthers(ethers);
    overrideConsoleLog();
  });

  beforeEach(async function () {
    await fs.emptyDir(tempDir);
    await fs.copy(path.resolve(__dirname, "./fixtures"), tempDir);
    turfAttributesJson = require(path.resolve(tempDir, "attributes/turfAttributes.json"));
    farmAttributesJson = require(path.resolve(tempDir, "attributes/farmAttributes.json"));
  });

  after(async function () {
    restoreConsoleLog();
    await fs.emptyDir(tempDir);
  });

  async function getSignature(hash, privateKey) {
    return signPackedData(hash, privateKey);
  }

  async function depositToken(user, amount, depositId, what = "Seed") {
    let nonce = randomNonce();
    let hash = await pool.hashDeposit(user.address, amount, depositId, nonce);
    let signature0 = getSignature(hash, validator0PK);
    return pool.connect(user)[`deposit${what}`](amount, depositId, nonce, signature0);
  }

  async function depositSeedAndPayOtherUser(user, amount, depositId, nftType, recipient) {
    let nonce = randomNonce();
    let hash = await pool.hashDepositAndPay(user.address, amount, depositId, nftType, recipient, nonce);
    let signature0 = getSignature(hash, validator0PK);
    return pool.connect(user).depositSeedAndPayOtherUser(amount, depositId, nftType, recipient, nonce, signature0);
  }

  async function initAndDeploy() {
    const amount = ethers.utils.parseEther("10000000000");

    seed = await deployUtils.deployProxy("SeedTokenMock2");

    await seed.mint(renter.address, amount);
    await seed.mint(buyer1.address, amount);
    await seed.mint(buyer2.address, amount);
    await seed.mint(buyer3.address, amount);
    await seed.mint(buyer4.address, amount);
    await seed.mint(buyer5.address, amount);

    bud = await deployUtils.deployProxy("BudTokenMock");
    await bud.mint(buyer1.address, amount);

    turf = await deployUtils.deployProxy("Turf", "https://meta.mob.land/turfs/");
    await turf.setMaxSupply(100);

    farm = await deployUtils.deployProxy("Farm", "https://meta.mob.land/farms/");
    await farm.setMaxSupply(5000);

    minter = await deployUtils.deploy("MinterMock", turf.address, farm.address);
    await turf.setFactory(minter.address, true);
    await farm.setFactory(minter.address, true);

    pool = await deployUtils.deployProxy("GamePool", turf.address, farm.address, seed.address, bud.address);

    /// TODO maybe we can add a function to do the three saves at one time
    await turf.setGame(pool.address);
    await turf.setDefaultPlayer(pool.address);
    await turf.setLocker(pool.address);

    await farm.setGame(pool.address);
    await farm.setDefaultPlayer(pool.address);
    await farm.setLocker(pool.address);

    expect(await pool.setValidator(0, validator0.address))
      .emit(pool, "ValidatorSet")
      .withArgs(0, validator0.address);
    expect(await pool.setValidator(1, validator1.address))
      .emit(pool, "ValidatorSet")
      .withArgs(1, validator1.address);

    await bud.setMinter(pool.address, true);
  }

  function randomUint32() {
    let d = Date.now() / 1000;
    return Math.round(d * Math.random());
  }

  async function mintAndInitTokens() {
    // 49 turfs
    await minter.mintTurf(buyer1.address, 10);
    await minter.mintTurf(buyer2.address, 10);
    await minter.mintTurf(buyer3.address, 10);
    await minter.mintTurf(buyer4.address, 10);
    await minter.mintTurf(buyer5.address, 9);

    let i = 1;
    for (let attr of turfAttributesJson) {
      await turf.preInitializeAttributesFor(i, attr.level);
      i++;
    }

    // 200 farms
    for (let i = 0; i < 2; i++) {
      await minter.mintFarm(buyer1.address, 20);
      await minter.mintFarm(buyer2.address, 20);
      await minter.mintFarm(buyer3.address, 20);
      await minter.mintFarm(buyer4.address, 20);
      await minter.mintFarm(buyer5.address, 20);
    }

    i = 1;
    for (let attr of farmAttributesJson) {
      let attributes = attr.level | (attr.farmState << 8) | (attr.currentHP << 16);
      await farm.preInitializeAttributesFor(i, attributes);
      i++;
    }
  }

  beforeEach(async function () {
    await initAndDeploy();
  });

  it("should Stake Turf, Farm and check Deposit", async function () {
    await mintAndInitTokens();

    const turfId = 1;
    const farmId = 1;

    await turf.connect(buyer1).approve(pool.address, turfId);

    expect(await pool.getNumberOfStakes(buyer1.address, turfTokenType)).equal(0);

    expect(await pool.connect(buyer1).stakeAsset(turfTokenType, turfId))
      .emit(turf, "Locked(uint256,bool)")
      .withArgs(turfId, true);

    expect(await pool.getNumberOfStakes(buyer1.address, turfTokenType)).equal(1);

    const [stakeIndex] = await pool.getStakeIndexByTokenId(buyer1.address, turfTokenType, 1, true);
    expect(stakeIndex).equal(0);

    expect((await pool.getStakeByIndex(buyer1.address, turfTokenType, 0)).tokenId).equal(turfId);

    await farm.connect(buyer1).approve(pool.address, farmId);

    await pool.connect(buyer1).stakeAsset(farmTokenType, farmId);
    await expect(pool.connect(buyer1).stakeAsset(farmTokenType, farmId)).revertedWith("farmAlreadyLocked()");

    let nonce = randomNonce();
    let hash = await pool.hashUnstake(turfTokenType, turfId, stakeIndex, nonce);
    let signature0 = getSignature(hash, validator0PK);
    let signature1 = getSignature(hash, validator1PK);

    expect(await pool.connect(buyer1).unstakeAsset(turfTokenType, turfId, stakeIndex, nonce, signature0, signature1))
      .emit(turf, "Locked(uint256,bool)")
      .withArgs(turfId, false);

    nonce = randomNonce();
    hash = await pool.hashUnstake(farmTokenType, farmId, stakeIndex, nonce);
    signature0 = getSignature(hash, validator0PK);
    signature1 = getSignature(hash, validator1PK);

    expect(await pool.connect(buyer1).unstakeAsset(farmTokenType, farmId, stakeIndex, nonce, signature0, signature1))
      .emit(farm, "Locked(uint256,bool)")
      .withArgs(farmId, false);

    expect((await pool.getStakeByIndex(buyer1.address, turfTokenType, 0)).unlockedAt).greaterThan(0);

    const seedAmount = ethers.utils.parseEther("1000");

    await seed.connect(buyer1).approve(pool.address, seedAmount);
    let id = 1234321;
    expect(await depositToken(buyer1, seedAmount, id))
      .emit(pool, "NewDeposit")
      .withArgs(id, buyer1.address, await pool.SEED(), seedAmount);

    const budAmount = seedAmount.mul(10);

    nonce = randomNonce();
    let opId = randomNonce();
    let deadline = (await getTimestamp()) + 24 * 3600;
    hash = await pool.hashHarvesting(buyer1.address, budAmount, deadline, nonce, opId);
    signature0 = getSignature(hash, validator0PK);
    signature1 = getSignature(hash, validator1PK);

    expect(await pool.connect(buyer1).harvest(budAmount, deadline, nonce, opId, signature0, signature1))
      .emit(pool, "Harvested")
      .withArgs(buyer1.address, budAmount, opId);

    await expect(pool.connect(buyer1).harvest(budAmount, deadline, nonce, opId, signature0, signature1)).revertedWith(
      "signatureAlreadyUsed()"
    );

    const turfAttributes = await turf.attributesOf(turfId, pool.address, 0);
    expect(turfAttributes).equal(1);
    let attr = {
      level: 2,
    };
    nonce = randomNonce();
    hash = await pool.hashTurfAttributes(turfId, attr, nonce);
    signature0 = getSignature(hash, validator0PK);
    signature1 = getSignature(hash, validator1PK);
    await pool.updateTurfAttributes(turfId, attr, nonce, signature0, signature1);
    expect(await turf.attributesOf(turfId, pool.address, 0)).equal(2);

    expect(pool.updateTurfAttributes(turfId, attr, nonce, signature0, signature1)).revertedWith("signatureAlreadyUsed()");

    const farmAttributes = cleanStruct(await pool.getFarmAttributes(farmId));
    expect(farmAttributes.level).equal(1);
    expect(farmAttributes.farmState).equal(1);
    expect(farmAttributes.currentHP).equal(600);
    expect(farmAttributes.weedReserves).equal(0);
    attr = {
      level: 2,
      farmState: 0,
      currentHP: 13234,
      weedReserves: 7654,
    };
    nonce = randomNonce();
    hash = await pool.hashFarmAttributes(farmId, attr, nonce);
    signature0 = getSignature(hash, validator0PK);
    signature1 = getSignature(hash, validator1PK);
    await pool.updateFarmAttributes(farmId, attr, nonce, signature0, signature1);
    let farmAttributes2 = cleanStruct(await pool.getFarmAttributes(farmId));
    expect(farmAttributes2.level).equal(2);
    expect(farmAttributes2.farmState).equal(0);
    expect(farmAttributes2.currentHP).equal(13234);
    expect(farmAttributes2.weedReserves).equal(7654);
  });
});
