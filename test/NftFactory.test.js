const {expect, assert} = require("chai");

const {initEthers, increaseBlockTimestampBy} = require("./helpers");
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");
const DeployUtils = require("../scripts/lib/DeployUtils");

// tests to be fixed

describe("NftFactory", function () {
  let owner, whitelisted, notWhitelisted;
  let Whitelist, wl;
  let TurfToken, turf;
  let NftFactory, farm;
  let seed, busd;

  const deployUtils = new DeployUtils(ethers);

  before(async function () {
    [owner, whitelisted, notWhitelisted] = await ethers.getSigners();
    Whitelist = await ethers.getContractFactory("WhitelistSlot");
    TurfToken = await ethers.getContractFactory("Turf");
    NftFactory = await ethers.getContractFactory("NftFactory");
    initEthers(ethers);
  });

  async function initAndDeploy() {
    const seedAmount = ethers.utils.parseEther("10000000000");
    const usdAmount = ethers.utils.parseEther("1000000");

    wl = await Whitelist.deploy();
    await wl.deployed();

    turf = await upgrades.deployProxy(TurfToken, ["https://s3.mob.land/turf/"]);
    await turf.deployed();

    busd = await deployUtils.deployProxy("SeedTokenMock");
    await busd.deployed();
    await busd.mint(whitelisted.address, usdAmount);
    await busd.mint(notWhitelisted.address, usdAmount);

    seed = await deployUtils.deployProxy("SeedTokenMock");
    await seed.deployed();
    await seed.mint(whitelisted.address, seedAmount);
    await seed.mint(notWhitelisted.address, seedAmount);

    farm = await upgrades.deployProxy(NftFactory);
    await farm.deployed();
    await farm.setPaymentToken(seed.address, true);
    await farm.setPaymentToken(busd.address, true);

    const id = 1;
    const amount = 5;
    await wl.mintBatch(whitelisted.address, [id], [amount], []);
    await wl.setBurnerForID(turf.address, id);
    await turf.setWhitelist(wl.address, (await getCurrentTimestamp()) + 1e4);
    await turf.setFactory(farm.address, true);
    await farm.setNewNft(turf.address);
  }

  async function setPrices() {
    await farm.setPrice(1, busd.address, ethers.utils.parseEther("100"));
    await farm.setPrice(1, seed.address, ethers.utils.parseEther("10000"));
  }

  describe("Buy tokens", async function () {
    beforeEach(async function () {
      await initAndDeploy();
      await setPrices();
    });

    it("should not buy because no payment", async function () {
      expect(farm.connect(whitelisted).buyTokens(1, busd.address, 3)).revertedWith("ERC20: insufficient allowance");
    });

    it("should revert maxSupply not set or defaultPlayer not set", async function () {
      expect(await turf.canMintAmount(3)).equal(false);
      const usdPrice = await farm.getPrice(1, busd.address);
      await busd.connect(whitelisted).approve(farm.address, usdPrice.mul(3));

      await expect(farm.connect(whitelisted).buyTokens(1, busd.address, 3)).revertedWith("CannotMint()");

      await turf.setMaxSupply(1000);

      expect(await turf.canMintAmount(3)).equal(true);
    });

    it("should buy tokens in BUSD", async function () {
      await turf.setMaxSupply(1000);
      expect(await wl.balanceOf(whitelisted.address, 1)).equal(5);
      const usdPrice = await farm.getPrice(1, busd.address);
      await busd.connect(whitelisted).approve(farm.address, usdPrice.mul(3));

      expect(await farm.connect(whitelisted).buyTokens(1, busd.address, 3))
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
      const seedPrice = await farm.getPrice(1, seed.address);
      await seed.connect(whitelisted).approve(farm.address, seedPrice.mul(3));

      expect(await farm.connect(whitelisted).buyTokens(1, seed.address, 3))
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
      const usdPrice = await farm.getPrice(1, busd.address);
      await busd.connect(notWhitelisted).approve(farm.address, usdPrice.mul(3));

      expect(await wl.balanceOf(notWhitelisted.address, 1)).equal(0);

      await expect(farm.connect(notWhitelisted).buyTokens(1, busd.address, 3)).revertedWith("NotEnoughWLSlots()");
    });
  });

  describe("Token prices", async function () {
    beforeEach(async function () {
      await initAndDeploy();
    });

    it("should get token price", async function () {
      await setPrices();
      const tokenId = 1;
      const price = ethers.utils.parseEther("100");
      expect(await farm.getPrice(tokenId, busd.address)).equal(price);
    });

    it("should set token price", async function () {
      const tokenId = 1;
      const price = ethers.utils.parseEther("1");
      expect(await farm.setPrice(tokenId, busd.address, price))
        .to.emit(farm, "NewPriceFor")
        .withArgs(tokenId, busd.address, price);
    });

    it("should get token price in Seeds", async function () {
      await setPrices();
      const tokenId = 1;
      const price = ethers.utils.parseEther("10000");
      expect(await farm.getPrice(tokenId, seed.address)).equal(price);
    });

    it("should set token price in Seeds", async function () {
      const tokenId = 1;
      const price = ethers.utils.parseEther("10000");
      expect(await farm.setPrice(tokenId, seed.address, price))
        .to.emit(farm, "NewPriceFor")
        .withArgs(tokenId, seed.address, price);
    });
  });

  describe("Buy tokens out of whitelisting period", async function () {
    beforeEach(async function () {
      await initAndDeploy();
      await setPrices();
    });
    it("should buy tokens when whitelist period ends", async function () {
      await turf.setMaxSupply(1000);
      const usdPrice = await farm.getPrice(1, busd.address);
      await busd.connect(notWhitelisted).approve(farm.address, usdPrice.mul(3));

      await increaseBlockTimestampBy((await getCurrentTimestamp()) + 1e4 + 10);

      expect(await farm.connect(notWhitelisted).buyTokens(1, busd.address, 3))
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
