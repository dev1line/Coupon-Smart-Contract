const { expect } = require("chai");
const { upgrades, ethers } = require("hardhat");
const { getCurrentTime, skipTime } = require("../utils");

describe("Dutch Auction:", () => {
  beforeEach(async () => {
    const accounts = await ethers.getSigners();
    owner = accounts[0];
    user1 = accounts[1];
    user2 = accounts[2];
    user3 = accounts[3];
    Admin = await ethers.getContractFactory("Admin");
    DutchAuction = await ethers.getContractFactory("DutchAuction");
    Treasury = await ethers.getContractFactory("Treasury");
    admin = await upgrades.deployProxy(Admin, [owner.address]);
    treasury = await upgrades.deployProxy(Treasury, [admin.address]);

    Token = await ethers.getContractFactory("CMCG");
    token = await Token.deploy(
      "CMC Global Token",
      "CMCG",
      ethers.utils.parseEther("10000"),
      treasury.address
    );

    NftTest = await ethers.getContractFactory("NftTest");
    nftTest = await upgrades.deployProxy(NftTest, [
      "NFT test",
      "NFT",
      token.address,
      250,
      ethers.utils.parseEther("1"),
      admin.address,
    ]);
    await admin.setPermittedPaymentToken(token.address, true);
    const currentTime = await getCurrentTime();
    const startingBid = ethers.utils.parseEther("1");
    dutchAuction = await upgrades.deployProxy(DutchAuction, [
      owner.address,
      nftTest.address,
      1,
      token.address,
      startingBid,
      currentTime + 1000,
      currentTime + 10000,
      1000,
    ]);
    await treasury
      .connect(owner)
      .distribute(
        token.address,
        owner.address,
        ethers.utils.parseEther("1000")
      );
    await treasury
      .connect(owner)
      .distribute(
        token.address,
        user1.address,
        ethers.utils.parseEther("1000")
      );
    await token
      .connect(user1)
      .approve(dutchAuction.address, ethers.utils.parseEther("10"));
    await token
      .connect(owner)
      .approve(dutchAuction.address, ethers.utils.parseEther("10"));
    await token
      .connect(owner)
      .approve(nftTest.address, ethers.utils.parseEther("1"));
    await nftTest.buy("uri.json");
    await nftTest.approve(dutchAuction.address, 1);
    await nftTest.transferFrom(owner.address, dutchAuction.address, 1);
  });

  describe("Deployment:", async () => {
    it("Check default state: ", async () => {
      const owner_ = await dutchAuction.owner();
      const nftReward = await dutchAuction.nftReward();
      const nftId = await dutchAuction.nftId();
      const startingPrice = await dutchAuction.startingPrice();

      expect(owner_).to.equal(owner.address);
      expect(nftReward).to.equal(nftTest.address);
      expect(nftId).to.equal(1);
      expect(startingPrice).to.equal(ethers.utils.parseEther("1"));
    });
  });

  describe("buy function:", async () => {
    it("should revert when buy before start time: ", async () => {
      await expect(
        dutchAuction.buy(ethers.utils.parseEther("1"))
      ).to.be.revertedWith("not started");
    });

    it("should revert when buy after end time: ", async () => {
      await skipTime(10001);
      await expect(
        dutchAuction.buy(ethers.utils.parseEther("1"))
      ).to.be.revertedWith("ended");
    });

    it("should revert when amount bid < price: ", async () => {
      await skipTime(1001);
      const price = await dutchAuction.getPrice();
      await expect(
        dutchAuction.buy(ethers.utils.parseEther("1") - price)
      ).to.be.revertedWith("value < price");
    });

    it("should buy success: ", async () => {
      await skipTime(1001);
      const price = await dutchAuction.getPrice();
      expect(await dutchAuction.buy(ethers.utils.parseEther("2")))
        .emit(dutchAuction, "Bought")
        .withArgs(owner.address, price);
    });
  });

  describe("withdraw function:", async () => {
    it("should revert when only owner can call: ", async () => {
      await expect(dutchAuction.connect(user1).withdraw()).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("should withdraw is ended success: ", async () => {
      await skipTime(1001);
      await dutchAuction.connect(user1).buy(ethers.utils.parseEther("2"));

      await dutchAuction.withdraw();
      expect(await dutchAuction.isEnded()).to.equal(true);
    });
    it("should withdraw not ended success: ", async () => {
      await skipTime(1001);

      await dutchAuction.withdraw();
      expect(await dutchAuction.isEnded()).to.equal(true);
    });
  });

  describe("getPrice function:", async () => {
    it("should get price success: ", async () => {
      await skipTime(1001);
      const price_before = await dutchAuction.getPrice();

      await skipTime(10001 * 100000);
      const price_after = await dutchAuction.getPrice();

      expect(parseInt(price_before.toString())).to.be.greaterThan(
        parseInt(price_after.toString())
      );
    });
  });
});
