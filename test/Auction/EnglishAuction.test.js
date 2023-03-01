const { expect } = require("chai");
const { upgrades, ethers } = require("hardhat");
const { getCurrentTime, skipTime } = require("../utils");

describe("English Auction:", () => {
  beforeEach(async () => {
    const accounts = await ethers.getSigners();
    owner = accounts[0];
    user1 = accounts[1];
    user2 = accounts[2];
    user3 = accounts[3];
    Admin = await ethers.getContractFactory("Admin");
    EnglishAuction = await ethers.getContractFactory("EnglishAuction");
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
    englishAuction = await upgrades.deployProxy(EnglishAuction, [
      owner.address,
      nftTest.address,
      1,
      token.address,
      startingBid,
      currentTime + 1000,
      currentTime + 10000,
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
      .approve(englishAuction.address, ethers.utils.parseEther("10"));
    await token
      .connect(owner)
      .approve(englishAuction.address, ethers.utils.parseEther("10"));
    await token
      .connect(owner)
      .approve(nftTest.address, ethers.utils.parseEther("1"));
    await nftTest.buy("uri.json");
    await nftTest.approve(englishAuction.address, 1);
    await nftTest.transferFrom(owner.address, englishAuction.address, 1);
  });

  describe("Deployment:", async () => {
    it("Check default state: ", async () => {
      const owner_ = await englishAuction.owner();
      const nftReward = await englishAuction.nftReward();
      const nftId = await englishAuction.nftId();
      const highestBid = await englishAuction.highestBid();

      expect(owner_).to.equal(owner.address);
      expect(nftReward).to.equal(nftTest.address);
      expect(nftId).to.equal(1);
      expect(highestBid).to.equal(ethers.utils.parseEther("1"));
    });
  });

  describe("bid function:", async () => {
    it("should revert when bid before start time: ", async () => {
      await expect(
        englishAuction.bid(ethers.utils.parseEther("1"))
      ).to.be.revertedWith("not started");
    });

    it("should revert when bid after end time: ", async () => {
      await skipTime(10001);
      await expect(
        englishAuction.bid(ethers.utils.parseEther("1"))
      ).to.be.revertedWith("ended");
    });
    it("should revert when bid after end time: ", async () => {
      await skipTime(1001);
      expect(await englishAuction.end())
        .emit(englishAuction.address, "End")
        .withArgs(user1.address, ethers.utils.parseEther("0"));
      await expect(
        englishAuction.bid(ethers.utils.parseEther("1"))
      ).to.be.revertedWith("ended");
    });

    it("should revert when amount bid < highest: ", async () => {
      await skipTime(1001);
      await expect(
        englishAuction.bid(ethers.utils.parseEther("1"))
      ).to.be.revertedWith("amount < highest");
      await expect(
        englishAuction.bid(ethers.utils.parseEther("0.1"))
      ).to.be.revertedWith("amount < highest");
    });

    it("should bid success: ", async () => {
      await skipTime(1001);
      await englishAuction.bid(ethers.utils.parseEther("2"));
      expect(await englishAuction.highestBid()).to.equal(
        ethers.utils.parseEther("2")
      );
    });
  });

  describe("withdraw function:", async () => {
    it("should revert when highest bidder can not withdraw: ", async () => {
      await skipTime(1001);
      await englishAuction.connect(user1).bid(ethers.utils.parseEther("2"));
      expect(await englishAuction.highestBid()).to.equal(
        ethers.utils.parseEther("2")
      );
      await expect(englishAuction.connect(user1).withdraw()).to.be.revertedWith(
        "highest bidder can not withdraw"
      );
    });

    it("should withdraw success: ", async () => {
      await skipTime(1001);
      await englishAuction.connect(user1).bid(ethers.utils.parseEther("2"));
      expect(await englishAuction.highestBid()).to.equal(
        ethers.utils.parseEther("2")
      );

      await englishAuction.withdraw();
      expect(await englishAuction.bids(owner.address)).to.equal(0);
    });
  });

  describe("end function:", async () => {
    it("should revert when only owner can call: ", async () => {
      await expect(englishAuction.connect(user1).end()).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("should revert when bid before start time: ", async () => {
      await expect(englishAuction.end()).to.be.revertedWith("not started");
    });

    it("should revert when bid after end time: ", async () => {
      await skipTime(10001);
      await expect(englishAuction.end()).to.be.revertedWith("ended");
    });

    it("should end success: ", async () => {
      await skipTime(1001);
      await englishAuction.connect(user1).bid(ethers.utils.parseEther("2"));
      expect(await englishAuction.highestBid()).to.equal(
        ethers.utils.parseEther("2")
      );

      await englishAuction.withdraw();
      expect(await englishAuction.bids(owner.address)).to.equal(0);
      expect(await englishAuction.end())
        .emit(englishAuction.address, "End")
        .withArgs(user1.address, ethers.utils.parseEther("2"));
    });
    it("should end success with not winner: ", async () => {
      await skipTime(1001);

      expect(await englishAuction.end())
        .emit(englishAuction.address, "End")
        .withArgs(user1.address, ethers.utils.parseEther("0"));
    });
  });
});
