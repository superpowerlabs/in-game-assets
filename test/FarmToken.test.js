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
    nft = await upgrades.deployProxy(FarmToken, ["https://s3.mob.land/farm/"]);
    await nft.deployed();

    farm = await FarmMock.deploy(nft.address);
    await farm.deployed();
  }

  async function configure() {
    await nft.setMaxSupply(1000);
    await nft.setFactory(farm.address, true);
  }

  describe("constructor and initialization", async function () {
    beforeEach(async function () {
      await initAndDeploy();
    });

    it("should revert if not authorized", async function () {
      await expect(await nft.factories(farm.address)).equal(false);
    });
  });

  describe("attributes", async function () {
    beforeEach(async function () {
      await initAndDeploy();
    });

    it("should set up attributes on chain and get them", async function () {
      await nft.setGame(game.address);
      await nft.setMaxSupply(1000);
      await nft.mint(holder.address, 1);
      const attributes = {
        level: 2,
        farmState: 243,
        currentHP: 2736543,
        weedReserves: 33322343
      }

      await nft.connect(game).updateAttributes(1, attributes);
      let attrs = await nft.attributesOf(1)
      expect(attrs).equal("uint8 level:2;uint8 farmState:243;uint32 currentHP:2736543;uint32 weedReserves:33322343")
    });

  });
});
