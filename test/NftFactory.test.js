const {expect, assert} = require("chai");

const {initEthers} = require("./helpers");
const {getCurrentTimestamp} = require("hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp");

// tests to be fixed

describe("NftFactory", function () {
  let owner, whitelisted, notWhitelisted;
  let Whitelist, wl;
  let TurfToken, nft;
  let NftFactory, farm;

  before(async function () {
    [owner, whitelisted, notWhitelisted] = await ethers.getSigners();
    Whitelist = await ethers.getContractFactory("WhitelistSlot");
    TurfToken = await ethers.getContractFactory("Turf");
    NftFactory = await ethers.getContractFactory("NftFactory");
    initEthers(ethers);
  });

  async function initAndDeploy() {
    wl = await Whitelist.deploy();
    await wl.deployed();

    nft = await upgrades.deployProxy(TurfToken, ["https://s3.mob.land/turf/"]);
    await nft.deployed();

    farm = await upgrades.deployProxy(NftFactory, []);
    await farm.deployed();

    const id = 1;
    const amount = 5;
    await wl.mintBatch(whitelisted.address, [id], [amount], []);
    await wl.setBurnerForID(nft.address, id);
    await nft.setWhitelist(wl.address, getCurrentTimestamp() + 1e4);
    await nft.setFactory(farm.address, true);
    await farm.setNewNft(nft.address);
    await farm.setPrice(1, ethers.utils.parseEther("1"));
  }

  describe("Buy tokens", async function () {
    beforeEach(async function () {
      await initAndDeploy();
    });

    it("should not buy because no payment", async function () {
      expect(farm.connect(whitelisted).buyTokens(1, 3)).revertedWith("NftFactory: insufficient payment");
    });

    it("should revert maxSupply not set or defaultPlayer not set", async function () {
      expect(await nft.canMintAmount(3)).equal(false);

      await expect(
        farm.connect(whitelisted).buyTokens(1, 3, {
          value: ethers.BigNumber.from(await farm.getPrice(1)).mul(3),
        })
      ).revertedWith("SuperpowerNFT: can not mint");

      await nft.setMaxSupply(1000);

      expect(await nft.canMintAmount(3)).equal(true);
    });

    it("should buy tokens", async function () {
      await nft.setMaxSupply(1000);
      expect(await wl.balanceOf(whitelisted.address, 1)).equal(5);

      expect(
        await farm.connect(whitelisted).buyTokens(1, 3, {
          value: ethers.BigNumber.from(await farm.getPrice(1)).mul(3),
        })
      )
        .to.emit(nft, "Transfer")
        .withArgs(ethers.constants.AddressZero, whitelisted.address, 1)
        .to.emit(nft, "Transfer")
        .withArgs(ethers.constants.AddressZero, whitelisted.address, 2)
        .to.emit(nft, "Transfer")
        .withArgs(ethers.constants.AddressZero, whitelisted.address, 3);

      expect(await nft.nextTokenId()).equal(4);
      expect(await wl.balanceOf(whitelisted.address, 1)).equal(2);

      expect(
        await nft
          .connect(whitelisted)
          ["safeTransferFrom(address,address,uint256)"](whitelisted.address, notWhitelisted.address, 1)
      )
        .to.emit(nft, "Transfer")
        .withArgs(whitelisted.address, notWhitelisted.address, 1);
    });

    it("should can not buy tokens because not whitelisted", async function () {
      await nft.setMaxSupply(1000);

      expect(await wl.balanceOf(notWhitelisted.address, 1)).equal(0);

      await expect(
        farm.connect(notWhitelisted).buyTokens(1, 3, {
          value: ethers.BigNumber.from(await farm.getPrice(1)).mul(3),
        })
      ).revertedWith("SuperpowerNFT: not enough slot in whitelist");
    });

    it("should buy tokens when whitelist period ends", async function () {
      await nft.setMaxSupply(1000);

      await nft.setWhitelist(ethers.constants.AddressZero, 0);

      expect(
        await farm.connect(notWhitelisted).buyTokens(1, 3, {
          value: ethers.BigNumber.from(await farm.getPrice(1)).mul(3),
        })
      )
        .to.emit(nft, "Transfer")
        .withArgs(ethers.constants.AddressZero, notWhitelisted.address, 1)
        .to.emit(nft, "Transfer")
        .withArgs(ethers.constants.AddressZero, notWhitelisted.address, 2)
        .to.emit(nft, "Transfer")
        .withArgs(ethers.constants.AddressZero, notWhitelisted.address, 3);

      expect(await nft.nextTokenId()).equal(4);
    });
  });
});
