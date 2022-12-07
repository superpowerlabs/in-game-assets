const {expect, assert} = require("chai");

const {initEthers} = require("./helpers");

// tests to be fixed

describe("FarmToken", function () {
  let FarmToken, nft;
  let FarmTokenBridged, bridgedNft;
  let FarmMock, farm;
  let owner, holder, game;

  before(async function () {
    [owner, holder, game] = await ethers.getSigners();
    FarmToken = await ethers.getContractFactory("FarmTokenMock");
    FarmMock = await ethers.getContractFactory("FarmMock");
    initEthers(ethers);
  });

  async function initAndDeploy() {
    nft = await upgrades.deployProxy(FarmToken, ["https://meta.mob.land/farms/"]);
    await nft.deployed();

    farm = await FarmMock.deploy(nft.address);
    await farm.deployed();
  }

  describe("constructor and initialization", async function () {
    beforeEach(async function () {
      await initAndDeploy();
    });

    it("should revert if not authorized", async function () {
      await expect(await nft.isFactory(farm.address)).equal(false);
    });
  });
});
