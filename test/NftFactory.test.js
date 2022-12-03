const {expect, assert} = require("chai");

const {initEthers, increaseBlockTimestampBy} = require("./helpers");
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");
const DeployUtils = require("../scripts/lib/DeployUtils");

// tests to be fixed

describe("NftFactory", function () {
  let owner, whitelisted, notWhitelisted;
  let Whitelist, wl;
  let TurfToken, turf;
  let FarmToken, farm;
  let NftFactory, factory;
  let seed, busd;

  const deployUtils = new DeployUtils(ethers);

  function pe(amount) {
    return ethers.utils.parseEther(amount.toString());
  }

  before(async function () {
    [owner, whitelisted, notWhitelisted] = await ethers.getSigners();
    Whitelist = await ethers.getContractFactory("WhitelistSlot");
    TurfToken = await ethers.getContractFactory("Turf");
    FarmToken = await ethers.getContractFactory("Farm");
    NftFactory = await ethers.getContractFactory("NftFactory");
    initEthers(ethers);
  });

  async function initAndDeploy(configure) {
    const seedAmount = pe("10000000000");
    const usdAmount = pe("1000000");

    turf = await upgrades.deployProxy(TurfToken, ["https://s3.mob.land/turf/"]);
    await turf.deployed();
    await turf.setMaxSupply(1000);

    farm = await upgrades.deployProxy(FarmToken, ["https://s3.mob.land/farm/"]);
    await farm.deployed();
    await farm.setMaxSupply(5000);

    busd = await deployUtils.deployProxy("SeedTokenMock");
    await busd.deployed();
    await busd.mint(whitelisted.address, usdAmount);
    await busd.mint(notWhitelisted.address, usdAmount);

    seed = await deployUtils.deployProxy("SeedTokenMock");
    await seed.deployed();
    await seed.mint(whitelisted.address, seedAmount);
    await seed.mint(notWhitelisted.address, seedAmount);

    factory = await upgrades.deployProxy(NftFactory);
    await factory.deployed();
    await factory.setPaymentToken(seed.address, true);
    await factory.setPaymentToken(busd.address, true);

    wl = await Whitelist.deploy(factory.address);
    await wl.deployed();

    await factory.setWl(wl.address);

    const amount = 5;

    await wl.mintBatch(whitelisted.address, [1], [amount], []);
    await wl.mintBatch(whitelisted.address, [2], [amount], []);

    await turf.setFactory(factory.address, true);
    await farm.setFactory(factory.address, true);

    await factory.setNewNft(turf.address);
    await factory.setNewNft(farm.address);

    if (configure) {
      const ts = await getCurrentTimestamp();
      await factory.newSale(1, 100, ts, ts + 1000, 1, [busd.address, seed.address]);
      await factory.setPrice(1, busd.address, pe("100"), pe("130"));
      await factory.setPrice(1, seed.address, pe("10000"), pe("13000"));
      await factory.newSale(2, 300, ts, ts + 1000, 2, [busd.address, seed.address]);
      await factory.setPrice(2, busd.address, pe("100"), pe("130"));
      await factory.setPrice(2, seed.address, pe("10000"), pe("13000"));
    }
  }

  describe("Buy tokens", async function () {
    beforeEach(async function () {
      await initAndDeploy(true);
    });

    it("should not buy because no payment", async function () {
      await expect(factory.connect(whitelisted).buyTokens(1, busd.address, 3)).revertedWith("ERC20: insufficient allowance");
    });

    it("should buy tokens in BUSD", async function () {
      await turf.setMaxSupply(1000);
      expect(await wl.balanceOf(whitelisted.address, 1)).equal(5);
      const usdPrice = await factory.getPrice(1, busd.address);
      await busd.connect(whitelisted).approve(factory.address, usdPrice.mul(3));

      expect(await factory.connect(whitelisted).buyTokens(1, busd.address, 3))
        .to.emit(turf, "Transfer")
        .withArgs(ethers.constants.AddressZero, whitelisted.address, 1)
        .to.emit(turf, "Transfer")
        .withArgs(ethers.constants.AddressZero, whitelisted.address, 2)
        .to.emit(turf, "Transfer")
        .withArgs(ethers.constants.AddressZero, whitelisted.address, 3);

      expect(await turf.nextTokenId()).equal(4);
      expect(await wl.balanceOf(whitelisted.address, 1)).equal(2);

      expect(
        await turf
          .connect(whitelisted)
          ["safeTransferFrom(address,address,uint256)"](whitelisted.address, notWhitelisted.address, 1)
      )
        .to.emit(turf, "Transfer")
        .withArgs(whitelisted.address, notWhitelisted.address, 1);
    });

    it("should buy tokens in SEED", async function () {
      await turf.setMaxSupply(1000);
      expect(await wl.balanceOf(whitelisted.address, 1)).equal(5);
      const seedPrice = await factory.getPrice(1, seed.address);
      await seed.connect(whitelisted).approve(factory.address, seedPrice.mul(3));

      expect(await factory.connect(whitelisted).buyTokens(1, seed.address, 3))
        .to.emit(turf, "Transfer")
        .withArgs(ethers.constants.AddressZero, whitelisted.address, 1)
        .to.emit(turf, "Transfer")
        .withArgs(ethers.constants.AddressZero, whitelisted.address, 2)
        .to.emit(turf, "Transfer")
        .withArgs(ethers.constants.AddressZero, whitelisted.address, 3);

      expect(await turf.nextTokenId()).equal(4);
      expect(await wl.balanceOf(whitelisted.address, 1)).equal(2);

      expect(
        await turf
          .connect(whitelisted)
          ["safeTransferFrom(address,address,uint256)"](whitelisted.address, notWhitelisted.address, 1)
      )
        .to.emit(turf, "Transfer")
        .withArgs(whitelisted.address, notWhitelisted.address, 1);
    });

    it("should can not buy tokens because not whitelisted", async function () {
      await turf.setMaxSupply(1000);
      const usdPrice = await factory.getPrice(1, busd.address);
      await busd.connect(notWhitelisted).approve(factory.address, usdPrice.mul(3));

      expect(await wl.balanceOf(notWhitelisted.address, 1)).equal(0);

      await expect(factory.connect(notWhitelisted).buyTokens(1, busd.address, 3)).revertedWith("NotEnoughWLSlots()");
    });
  });

  describe("Token prices", async function () {
    beforeEach(async function () {
      await initAndDeploy(true);
    });

    it("should get token price", async function () {
      const tokenId = 1;
      expect(await factory.getPrice(tokenId, busd.address)).equal(pe("130"));
      expect(await factory.getWlPrice(tokenId, busd.address)).equal(pe("100"));
    });

    it("should set token price", async function () {
      const tokenId = 1;
      expect(await factory.setPrice(tokenId, busd.address, pe("1"), pe("1.4")))
        .to.emit(factory, "NewPriceFor")
        .withArgs(tokenId, busd.address, pe("1"), pe("1.4"));
    });

    it("should get token price in Seeds", async function () {
      const tokenId = 1;
      const price = pe("13000");
      expect(await factory.getPrice(tokenId, seed.address)).equal(price);
    });

    it("should set token price in Seeds", async function () {
      const tokenId = 1;
      const price = pe("10000");
      expect(await factory.setPrice(tokenId, seed.address, price, price))
        .to.emit(factory, "NewPriceFor")
        .withArgs(tokenId, seed.address, price, price);
    });
  });

  describe("Buy tokens out of whitelisting period", async function () {
    beforeEach(async function () {
      await initAndDeploy(true);
    });
    it("should buy tokens when whitelist period ends", async function () {
      await turf.setMaxSupply(1000);
      const usdPrice = await factory.getPrice(1, busd.address);
      await busd.connect(notWhitelisted).approve(factory.address, usdPrice.mul(3));

      await increaseBlockTimestampBy((await getCurrentTimestamp()) + 1e4 + 10);

      expect(await factory.connect(notWhitelisted).buyTokens(1, busd.address, 3))
        .to.emit(turf, "Transfer")
        .withArgs(ethers.constants.AddressZero, notWhitelisted.address, 1)
        .to.emit(turf, "Transfer")
        .withArgs(ethers.constants.AddressZero, notWhitelisted.address, 2)
        .to.emit(turf, "Transfer")
        .withArgs(ethers.constants.AddressZero, notWhitelisted.address, 3);

      expect(await turf.nextTokenId()).equal(4);
    });
  });
});
