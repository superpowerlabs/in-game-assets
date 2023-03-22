const {expect, assert} = require("chai");

const {initEthers, overrideConsoleLog, restoreConsoleLog} = require("./helpers");

// tests to be fixed

describe("FarmToken", function () {
  let FarmToken, nft;
  let FarmTokenBridged, bridgedNft;
  let FarmMock, farm;
  let owner, game, holder, holder2, holder3;

  before(async function () {
    [owner, game, holder, holder2, holder3] = await ethers.getSigners();
    FarmToken = await ethers.getContractFactory("Farm");
    FarmMock = await ethers.getContractFactory("FarmMock");
    initEthers(ethers);
    overrideConsoleLog();
  });

  after(async function () {
    restoreConsoleLog();
  });

  async function initAndDeploy() {
    nft = await upgrades.deployProxy(FarmToken, ["https://meta.mob.land/farms/"]);
    await nft.deployed();
    await nft.setMaxSupply(5000);
    // this cannot be put in the initializer because we are testing a version
    // of a contract that has been already deployed in production
    farm = await FarmMock.deploy(nft.address);
    await farm.deployed();
    await nft.setFactory(farm.address, true);
    await expect(nft.setLocker(farm.address)).to.emit(nft, "LockerSet").withArgs(farm.address);

    await farm.mintTokens(holder.address, 25);
    await farm.mintTokens(holder.address, 25);
    await farm.mintTokens(holder.address, 25);
    await farm.mintTokens(holder.address, 25);
    for (let i = 1; i <= 100; i += 3) {
      await nft.connect(holder).approve(farm.address, i);
    }
    for (let i = 1; i <= 100; i += 3) {
      await expect(farm.lockToken(i)).to.emit(nft, "Locked").withArgs(i, true);
    }
    await expect(farm.lockToken(2)).revertedWith("LockerNotApproved()");
  }

  describe("constructor and initialization", async function () {
    beforeEach(async function () {
      await initAndDeploy();
    });

    it("should emit the expected events", async function () {
      await expect(nft.emitNewLockedEvent(), {
        gasLimit: 300000,
      })
        .to.emit(nft, "DefaultLocked")
        .to.emit(nft, "Locked")
        .withArgs(1, true)
        .to.emit(nft, "Locked")
        .withArgs(4, true)
        .to.emit(nft, "Locked")
        .withArgs(7, true)
        .to.emit(nft, "Locked")
        .withArgs(19, true)
        .to.emit(nft, "Locked")
        .withArgs(34, true);
    });
    it("should emit the expected number of events", async function () {
      // we need to stop the console capture to make this working
      restoreConsoleLog();

      let tx = await nft.emitNewLockedEvent({
        gasLimit: 300000,
      });
      await tx.wait();
      let events = await nft.queryFilter(nft.filters.Locked(), tx.blockNumber);
      expect(events.length).equal(14);

      tx = await nft.emitNewLockedEvent({
        gasLimit: 1000000,
      });
      await tx.wait();
      events = await nft.queryFilter(nft.filters.Locked(), tx.blockNumber);
      expect(events.length).equal(20);

      await expect(
        nft.emitNewLockedEvent({
          gasLimit: 300000,
        })
      ).revertedWith("NewLockedAlreadyEmitted()");
    });
  });
});
