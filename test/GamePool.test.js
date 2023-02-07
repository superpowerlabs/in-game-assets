process.env.NODE_ENV = "test";
const {expect, assert} = require("chai");
const _ = require("lodash");

const {initEthers, signPackedData, cleanStruct, randomNonce, increaseBlockTimestampBy, getTimestamp} = require("./helpers");
const turfAttributesJson = require("./fixtures/json/turfAttributes.json");
const farmAttributesJson = require("./fixtures/json/farmAttributes.json");

const DeployUtils = require("../scripts/lib/DeployUtils");

describe("GamePool", function () {
  let owner, holder, renter;
  let farm, turf, validator0, validator1;
  let seed;
  let bud;
  let pool;
  let minter, buyer1, buyer2, buyer3, buyer4, buyer5;
  const turfTokenType = 1;
  const farmTokenType = 2;
  const wrongTokenType = 4;

  const deployUtils = new DeployUtils(ethers);

  let validator0PK = "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a";
  let validator1PK = "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba";
  let validator2PK = "0x3141592653589793238462643383279502884197169399375105820974944592";

  before(async function () {
    [owner, holder, renter, buyer1, validator0, validator1, buyer2, buyer3, buyer4, buyer5] = await ethers.getSigners();
    initEthers(ethers);
  });

  async function getSignature(hash, privateKey) {
    return signPackedData(hash, privateKey);
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

  it("should fail to create a game pool if turf not a contract", async function () {
    expect(deployUtils.deployProxy("GamePool", buyer1.address, farm.address, seed.address, bud.address)).revertedWith(
      "Address: low-level delegate call failed"
    );
  });

  it("should fail to create a game pool if farm not a contract", async function () {
    expect(deployUtils.deployProxy("GamePool", turf.address, buyer1.address, seed.address, bud.address)).revertedWith(
      "Address: low-level delegate call failed"
    );
  });

  it("should fail to create a game pool if seed not a contract", async function () {
    expect(deployUtils.deployProxy("GamePool", turf.address, farm.address, buyer1.address, bud.address)).revertedWith(
      "Address: low-level delegate call failed"
    );
  });

  it("should fail to create a game pool if bud not a contract", async function () {
    expect(deployUtils.deployProxy("GamePool", turf.address, farm.address, seed.address, buyer1.address)).revertedWith(
      "Address: low-level delegate call failed"
    );
  });

  it("should test attributesOf", async function () {
    await mintAndInitTokens();
    const turfId = 1;
    const farmId = 1;
    const turfAttributes = await pool.attributesOf(turf.address, turfId);
    expect(turfAttributes).equal("uint8 level:1");
    const farmAttributes = await pool.attributesOf(farm.address, farmId);
    expect(farmAttributes).equal("uint8 level:1;uint8 farmState:1;uint32 currentHP:600;uint32 weedReserves:0");
  });

  it("should set burning points to 42", async function () {
    await pool.setConf(42);
    const getConf = await pool.conf();
    assert.equal(getConf.burningPoints, 42);
  });

  it("should withdraw seeds (happy path)", async function () {
    const seedAmount = ethers.utils.parseEther("10");
    await seed.connect(buyer1).approve(pool.address, seedAmount.mul(2));
    const id = 3627354;
    await depositToken(buyer1, seedAmount, id);

    expect(await seed.balanceOf(pool.address)).equal(seedAmount);

    const conf = await pool.conf();
    const burned = seedAmount.mul(conf.burningPoints).div(10000);
    expect(await pool.withdrawFT(await pool.SEED(), seedAmount, buyer2.address))
      .emit(seed, "Transfer")
      .withArgs(pool.address, buyer2.address, seedAmount.sub(burned));
  });

  it("should allow to deposit SEED and pay a renter", async function () {
    const seedAmount = ethers.utils.parseEther("10");
    await seed.connect(buyer1).approve(pool.address, seedAmount);
    const id = 3627354;
    const balance = await seed.balanceOf(buyer2.address);
    await depositSeedAndPayOtherUser(buyer1, seedAmount, id, turfTokenType, buyer2.address);
    const amountToOwner = seedAmount.mul(92).div(100);
    expect(await seed.balanceOf(buyer2.address)).equal(balance.add(amountToOwner));
    expect(await seed.balanceOf(pool.address)).equal(seedAmount.sub(amountToOwner));
  });

  it("should withdraw buds (happy path)", async function () {
    const budAmount = ethers.utils.parseEther("10");
    await bud.connect(buyer1).approve(pool.address, budAmount.mul(2));
    const id = 3627354;
    await depositToken(buyer1, budAmount, id, "Bud");

    expect(await bud.balanceOf(pool.address)).equal(budAmount);

    const conf = await pool.conf();
    const burned = budAmount.mul(conf.burningPoints).div(10000);
    expect(await pool.withdrawFT(await pool.BUD(), budAmount, buyer2.address))
      .emit(bud, "Transfer")
      .withArgs(pool.address, buyer2.address, budAmount.sub(burned));
  });

  it("should withdraw all buds when called with zeroo as amount (happy path)", async function () {
    const budAmount = ethers.utils.parseEther("100");
    await bud.connect(buyer1).approve(pool.address, budAmount.mul(2));
    const id = 3627354;
    await depositToken(buyer1, budAmount, id, "Bud");

    expect(await bud.balanceOf(pool.address)).equal(budAmount);

    const conf = await pool.conf();
    const burned = budAmount.mul(conf.burningPoints).div(10000);
    expect(await pool.withdrawFT(await pool.BUD(), 0, buyer2.address))
      .emit(bud, "Transfer")
      .withArgs(pool.address, buyer2.address, budAmount.sub(burned));
  });

  it("should try to withdraw seeds and fail (unhappy path)", async function () {
    const seedAmount = ethers.utils.parseEther("1000");
    await expect(pool.connect(buyer1).withdrawFT(await pool.SEED(), seedAmount, buyer2.address)).revertedWith(
      "Ownable: caller is not the owner"
    );
  });

  it("should try to withdraw seeds and fail (unhappy path)", async function () {
    const seedAmount = ethers.utils.parseEther("1000");
    await expect(pool.withdrawFT(await pool.SEED(), seedAmount, buyer2.address)).revertedWith("amountNotAvailable()");
  });

  it("should deposit buds (happy path)", async function () {
    const budAmount = ethers.utils.parseEther("100");
    const id = 3627322;
    await bud.connect(buyer1).approve(pool.address, budAmount);
    expect(await depositToken(buyer1, budAmount, id, "Bud"))
      .emit(pool, "NewDeposit")
      .withArgs(id, buyer1.address, await pool.BUD(), budAmount);
  });

  it("should try to deposit buds but fail for insufficient allowance (unhappy path)", async function () {
    const budAmount = ethers.utils.parseEther("1");
    const id = 3627322;
    await expect(depositToken(buyer1, budAmount, id, "Bud")).revertedWith("ERC20: insufficient allowance");
  });

  it("should fail to stake locked asset", async function () {
    await mintAndInitTokens();
    const turfId = 1;
    await turf.connect(buyer1).approve(pool.address, turfId);
    await pool.connect(buyer1).stakeAsset(turfTokenType, turfId);
    // second time should fail
    await expect(pool.connect(buyer1).stakeAsset(turfTokenType, turfId)).revertedWith("turfAlreadyLocked()");
  });

  it("should fail to stake an unsupported nft", async function () {
    await mintAndInitTokens();
    const turfId = 1;
    await turf.connect(buyer1).approve(pool.address, turfId);
    await pool.connect(buyer1).stakeAsset(turfTokenType, turfId);
    // second time should fail
    await expect(pool.connect(buyer1).stakeAsset(wrongTokenType, turfId)).revertedWith("unsupportedNFT()");
  });

  it("should return stake by index", async function () {
    await mintAndInitTokens();
    const turfId = 1;

    await turf.connect(buyer1).approve(pool.address, turfId);
    await pool.connect(buyer1).stakeAsset(turfTokenType, turfId);
    // const [stakeIndex] = await pool.getStakeIndexByTokenId(buyer1.address, turfTokenType, 1, true);

    let stake = await pool.connect(buyer1).getStakeByIndex(buyer1.address, turfTokenType, 0);
    expect(stake.tokenId).equal(1);
    expect(stake.unlockedAt).equal(0);
  });

  it("should return stake(0,0,0) when index is larger than user's stakes", async function () {
    await mintAndInitTokens();
    const turfId = 1;

    await turf.connect(buyer1).approve(pool.address, turfId);
    await pool.connect(buyer1).stakeAsset(turfTokenType, turfId);
    // const [stakeIndex] = await pool.getStakeIndexByTokenId(buyer1.address, turfTokenType, 1, true);

    let stake = await pool.connect(buyer1).getStakeByIndex(buyer1.address, turfTokenType, 42);
    expect(stake.tokenId).equal(0);
    expect(stake.lockedAt).equal(0);
    expect(stake.unlockedAt).equal(0);
  });

  it("should fail to unstake asset if sig0 == sig1", async function () {
    await mintAndInitTokens();
    const turfId = 1;

    await turf.connect(buyer1).approve(pool.address, turfId);
    await pool.connect(buyer1).stakeAsset(turfTokenType, turfId);
    const [stakeIndex] = await pool.getStakeIndexByTokenId(buyer1.address, turfTokenType, 1, true);

    let nonce = randomNonce();
    let hash = await pool.hashUnstake(turfTokenType, turfId, stakeIndex, nonce);
    let signature0 = getSignature(hash, validator0PK);

    await expect(
      pool.connect(buyer1).unstakeAsset(turfTokenType, turfId, stakeIndex, nonce, signature0, signature0)
    ).revertedWith("invalidSecondarySignature()");
  });

  it("should fail to unstake asset if sig0 invalid", async function () {
    await mintAndInitTokens();
    const turfId = 1;

    await turf.connect(buyer1).approve(pool.address, turfId);
    await pool.connect(buyer1).stakeAsset(turfTokenType, turfId);
    const [stakeIndex] = await pool.getStakeIndexByTokenId(buyer1.address, turfTokenType, 1, true);

    let nonce = randomNonce();
    let hash = await pool.hashUnstake(turfTokenType, turfId, stakeIndex, nonce);
    let signature0 = "0x364d6D0333432C3Ac016Ca832fb8594A8cE43Ca6";
    let signature1 = getSignature(hash, validator1PK);

    await expect(
      pool.connect(buyer1).unstakeAsset(turfTokenType, turfId, stakeIndex, nonce, signature0, signature1)
    ).revertedWith("ECDSA: invalid signature length");
  });

  it("should fail to unstake asset if sig0 not signed by validator0", async function () {
    await mintAndInitTokens();
    const turfId = 1;

    await turf.connect(buyer1).approve(pool.address, turfId);
    await pool.connect(buyer1).stakeAsset(turfTokenType, turfId);
    const [stakeIndex] = await pool.getStakeIndexByTokenId(buyer1.address, turfTokenType, 1, true);

    let nonce = randomNonce();
    let hash = await pool.hashUnstake(turfTokenType, turfId, stakeIndex, nonce);
    let signature0 = getSignature(hash, validator2PK);
    let signature1 = getSignature(hash, validator1PK);

    await expect(
      pool.connect(buyer1).unstakeAsset(turfTokenType, turfId, stakeIndex, nonce, signature0, signature1)
    ).revertedWith("invalidPrimarySignature()");
  });

  it("should fail to unstake asset if wrong token type", async function () {
    await mintAndInitTokens();
    const turfId = 1;

    await turf.connect(buyer1).approve(pool.address, turfId);
    await pool.connect(buyer1).stakeAsset(turfTokenType, turfId);
    const [stakeIndex] = await pool.getStakeIndexByTokenId(buyer1.address, turfTokenType, 1, true);

    let nonce = randomNonce();
    let hash = await pool.hashUnstake(turfTokenType, turfId, stakeIndex, nonce);
    let signature0 = getSignature(hash, validator0PK);
    let signature1 = getSignature(hash, validator1PK);

    await expect(
      pool.connect(buyer1).unstakeAsset(wrongTokenType, turfId, stakeIndex, nonce, signature0, signature1)
    ).revertedWith("invalidTokenType()");
  });

  it("should fail to unstake asset if asset not found", async function () {
    await mintAndInitTokens();
    const turfId = 1;
    const wrongTurfId = 10;

    await turf.connect(buyer1).approve(pool.address, turfId);
    await pool.connect(buyer1).stakeAsset(turfTokenType, turfId);
    const [stakeIndex] = await pool.getStakeIndexByTokenId(buyer1.address, turfTokenType, 1, true);

    let nonce = randomNonce();
    let hash = await pool.hashUnstake(turfTokenType, wrongTurfId, stakeIndex, nonce);
    let signature0 = getSignature(hash, validator0PK);
    let signature1 = getSignature(hash, validator1PK);

    await expect(
      pool.connect(buyer1).unstakeAsset(turfTokenType, wrongTurfId, stakeIndex, nonce, signature0, signature1)
    ).revertedWith("assetNotFound()");
  });

  it("should get user deposits", async function () {
    const budAmount = ethers.utils.parseEther("100");
    const id = 3627322;
    expect(await pool.getUserDeposits(buyer1.address)).deep.equal([]);
    await bud.connect(buyer1).approve(pool.address, budAmount);
    await depositToken(buyer1, budAmount, id, "Bud");
    let deposit = (await pool.getUserDeposits(buyer1.address))[0];
    expect(deposit.tokenType).to.equal(5); // 5 is Bud type
    expect(deposit.amount).to.equal(budAmount);
    // not testing deposit.timestamp
  });

  it("should get user stakes", async function () {
    await mintAndInitTokens();
    const turfId = 1;
    await turf.connect(buyer1).approve(pool.address, turfId);
    await pool.connect(buyer1).stakeAsset(turfTokenType, turfId);
    let stake = (await pool.getUserStakes(buyer1.address, turfTokenType))[0];
    expect(stake.tokenId).to.equal(1);
    expect(stake.unlockedAt).to.equal(0);
  });

  it("should return deposit by index when deposit exists", async function () {
    const budAmount = ethers.utils.parseEther("100");
    const id = 3627322;
    await bud.connect(buyer1).approve(pool.address, budAmount);
    await depositToken(buyer1, budAmount, id, "Bud");

    let deposit = await pool.depositByIndex(buyer1.address, 0);
    expect(deposit.tokenType).to.equal(5); // 5 is Bud type
    expect(deposit.amount).to.equal(budAmount);
    // not testing deposit.depositedAt
  });

  it("should return empty deposit when user has no deposits", async function () {
    let deposit = await pool.depositByIndex(buyer1.address, 42);
    expect(deposit.tokenType).to.equal(0);
    expect(deposit.amount).to.equal(0);
    expect(deposit.depositedAt).to.equal(0);
  });

  it("should return empty deposit when user has less deposits than index", async function () {
    const budAmount = ethers.utils.parseEther("100");
    const id = 3627322;
    await bud.connect(buyer1).approve(pool.address, budAmount);
    await depositToken(buyer1, budAmount, id, "Bud");

    let deposit = await pool.depositByIndex(buyer1.address, 42);
    expect(deposit.tokenType).to.equal(0);
    expect(deposit.amount).to.equal(0);
    expect(deposit.depositedAt).to.equal(0);
  });

  it("should return the total deposited amount", async function () {
    const seedTokenType = 4;
    const budTokenType = 5;

    const budAmount = ethers.utils.parseEther("100");
    const id = 3627322;
    await bud.connect(buyer1).approve(pool.address, budAmount);
    deposits1 = await pool.numberOfDeposits(buyer1.address);
    await depositToken(buyer1, budAmount, id, "Bud");
    deposits2 = await pool.numberOfDeposits(buyer1.address);
    expect(deposits2 - deposits1).to.equal(1);
  });

  it("should return the total number of deposits", async function () {
    let totalNbDeposits = await pool.numberOfDeposits(buyer1.address);
    expect(totalNbDeposits).equal(0);
    const budAmount = ethers.utils.parseEther("100");
    const id = 3627322;
    await bud.connect(buyer1).approve(pool.address, budAmount);
    await depositToken(buyer1, budAmount, id, "Bud");

    totalNbDeposits = await pool.numberOfDeposits(buyer1.address);
    expect(totalNbDeposits).equal(1);
  });

  it("should return a deposit by its id", async function () {
    const budAmount = ethers.utils.parseEther("100");
    const id = 3627322;
    let deposit = await pool.depositById(id);
    expect(deposit.tokenType).to.equal(0); // 5 is Bud type
    expect(deposit.amount).to.equal(0);
    // not testing deposit.depositedAt

    await bud.connect(buyer1).approve(pool.address, budAmount);
    await depositToken(buyer1, budAmount, id, "Bud");

    deposit = await pool.depositById(id);
    expect(deposit.tokenType).to.equal(5); // 5 is Bud type
    expect(deposit.amount).to.equal(budAmount);
    // not testing deposit.depositedAt
  });

  it("should harvest buds (Happy path)", async function () {
    const budAmount = ethers.utils.parseEther("10");
    let nonce = randomNonce();
    let opId = 18376452;
    let deadline = (await getTimestamp()) + 24 * 3600;
    let hash = await pool.hashHarvesting(buyer1.address, budAmount, deadline, nonce, opId);
    let signature0 = getSignature(hash, validator0PK);
    let signature1 = getSignature(hash, validator1PK);

    expect(await pool.connect(buyer1).harvest(budAmount, deadline, nonce, opId, signature0, signature1))
      .emit(pool, "Harvested")
      .withArgs(buyer1.address, budAmount, opId);
  });

  it("should fail to harvest buds if signature already used", async function () {
    const budAmount = ethers.utils.parseEther("10");
    let nonce = randomNonce();
    let opId = 18376452;
    let deadline = (await getTimestamp()) + 24 * 3600;
    let hash = await pool.hashHarvesting(buyer1.address, budAmount, deadline, nonce, opId);
    let signature0 = getSignature(hash, validator0PK);
    let signature1 = getSignature(hash, validator1PK);

    expect(await pool.connect(buyer1).harvest(budAmount, deadline, nonce, opId, signature0, signature1))
      .emit(pool, "Harvested")
      .withArgs(buyer1.address, budAmount, opId);

    await expect(pool.connect(buyer1).harvest(budAmount, deadline, nonce, opId, signature0, signature1)).revertedWith(
      "signatureAlreadyUsed()"
    );
  });

  it("should fail to harvest if signature0 is invalid", async function () {
    const budAmount = ethers.utils.parseEther("10");
    let nonce = randomNonce();
    let opId = 18376452;
    let deadline = (await getTimestamp()) + 24 * 3600;
    let hash = await pool.hashHarvesting(buyer1.address, budAmount, deadline, nonce, opId);
    let signature0 = getSignature(hash, validator0PK);

    await expect(pool.connect(buyer1).harvest(budAmount, deadline, nonce, opId, signature0, signature0)).revertedWith(
      "invalidSecondarySignature()"
    );
  });

  it("should fail to harvest if signature1 is invalid", async function () {
    const budAmount = ethers.utils.parseEther("10");
    let nonce = randomNonce();
    let opId = 18376452;
    let deadline = (await getTimestamp()) + 24 * 3600;
    let hash = await pool.hashHarvesting(buyer1.address, budAmount, deadline, nonce, opId);
    let signature1 = getSignature(hash, validator1PK);

    await expect(pool.connect(buyer1).harvest(budAmount, deadline, nonce, opId, signature1, signature1)).revertedWith(
      "invalidPrimarySignature()"
    );
  });

  it("should fail to harvest if expired", async function () {
    const budAmount = ethers.utils.parseEther("10");
    let nonce = randomNonce();
    let opId = 18376452;
    let deadline = (await getTimestamp()) + 24 * 3600;
    let hash = await pool.hashHarvesting(buyer1.address, budAmount, deadline, nonce, opId);
    let signature0 = getSignature(hash, validator0PK);
    let signature1 = getSignature(hash, validator1PK);

    increaseBlockTimestampBy(36 * 3600);

    await expect(pool.connect(buyer1).harvest(budAmount, deadline, nonce, opId, signature0, signature1)).revertedWith(
      "harvestingExpired()"
    );
  });

  it("should initialize turf", async function () {
    await minter.mintTurf(buyer1.address, 1);
    await turf.connect(buyer1).approve(pool.address, 1);
    const turfId = 1;
    await expect(pool.initializeTurf(turfId)).emit(turf, "AttributesInitializedFor").withArgs(1, pool.address);
  });

  it("should initialize farm", async function () {
    await minter.mintFarm(buyer1.address, 1);
    await farm.connect(buyer1).approve(pool.address, 1);
    const farmId = 1;
    await expect(pool.initializeFarm(farmId)).emit(farm, "AttributesInitializedFor").withArgs(1, pool.address);
  });

  it("should get turf attributes", async function () {
    const turfId = 1;
    await pool.getTurfAttributes(turfId);
  });
});
