const {expect, assert} = require("chai");

const {initEthers} = require("./helpers");

// tests to be fixed

describe("TurfToken", function () {
  let TurfToken, nft;
  let TurfTokenBridged, bridgedNft;
  let FarmMock, farm;
  let owner, holder;

  before(async function () {
    [owner, holder] = await ethers.getSigners();
    TurfToken = await ethers.getContractFactory("Turf");
    TurfTokenBridged = await ethers.getContractFactory("TurfBridged");
    FarmMock = await ethers.getContractFactory("FarmMock");

    initEthers(ethers);
  });

  async function initAndDeploy() {
    nft = await upgrades.deployProxy(TurfToken, ["https://s3.mob.land/turf/"]);
    await nft.deployed();

    bridgedNft = await upgrades.deployProxy(TurfToken, ["https://s3.mob.land/turf/"]);
    await bridgedNft.deployed();

    farm = await FarmMock.deploy(nft.address);
    await farm.deployed();
  }

  describe("constructor and initialization", async function () {
    beforeEach(async function () {
      await initAndDeploy();
    });

    it("should revert if not authorized", async function () {
      await expect(await nft.factories(farm.address)).equal(false);
    });
  });
});
