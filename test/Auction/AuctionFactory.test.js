const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const { expect } = require("chai");
const { upgrades, ethers } = require("hardhat");
const { getCurrentTime, skipTime } = require("../utils");

describe("Auction Factory:", () => {
  beforeEach(async () => {
    const accounts = await ethers.getSigners();
    owner = accounts[0];
    user1 = accounts[1];
    user2 = accounts[2];
    user3 = accounts[3];
    Admin = await ethers.getContractFactory("Admin");
    AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    EnglishAuction = await ethers.getContractFactory("EnglishAuction");
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

    englishAuctionTemplate = await EnglishAuction.deploy();
    dutchAuctionTemplate = await DutchAuction.deploy();
    auctionFactory = await upgrades.deployProxy(AuctionFactory, [
      dutchAuctionTemplate.address,
      englishAuctionTemplate.address,
      admin.address,
    ]);
    await treasury.distribute(
      token.address,
      owner.address,
      ethers.utils.parseEther("1000")
    );
    await treasury.distribute(
      token.address,
      user1.address,
      ethers.utils.parseEther("1000")
    );
    await token
      .connect(user1)
      .approve(auctionFactory.address, ethers.utils.parseEther("10"));
    await token
      .connect(owner)
      .approve(auctionFactory.address, ethers.utils.parseEther("10"));
    await token
      .connect(owner)
      .approve(nftTest.address, ethers.utils.parseEther("1"));
    await token
      .connect(user1)
      .approve(nftTest.address, ethers.utils.parseEther("1"));
    await nftTest.buy("uri.json");
    await nftTest.approve(auctionFactory.address, 1);
    await nftTest.connect(user1).buy("uri.json");
    await nftTest.connect(user1).approve(auctionFactory.address, 2);
    // await nftTest.transferFrom(owner.address, englishAuction.address, 1);
  });

  describe("Deployment:", async () => {
    it("Check default state: ", async () => {
      const dutchTemplate = await auctionFactory.dutchTemplate();
      const englishTemplate = await auctionFactory.englishTemplate();

      expect(dutchTemplate).to.equal(dutchAuctionTemplate.address);
      expect(englishTemplate).to.equal(englishAuctionTemplate.address);
    });
  });

  describe("create function:", async () => {
    it("should revert when paused: ", async () => {
      await auctionFactory.setPause(true);
      const startingBid = ethers.utils.parseEther("1");
      const currentTime = await getCurrentTime();
      await expect(
        auctionFactory.create(
          0,
          nftTest.address,
          1,
          token.address,
          startingBid,
          currentTime,
          currentTime + 1000,
          10
        )
      ).to.be.revertedWith("Pausable: paused");
    });

    // it("should revert when clone auction error: ", async () => {
    //   const startingBid = ethers.utils.parseEther("1");
    //   const currentTime = await getCurrentTime();
    //   await nftTest.connect(owner).approve(auctionFactory.address, 1);
    //   await expect(
    //     auctionFactory.create(
    //       0,
    //       nftTest.address,
    //       1,
    //       token.address,
    //       startingBid,
    //       currentTime,
    //       currentTime + 1000,
    //       10
    //     )
    //   ).to.be.revertedWith("CloneAuctionFailed()");
    // });

    it("should create success: ", async () => {
      const startingBid = ethers.utils.parseEther("1");
      const currentTime = await getCurrentTime();
      await nftTest.connect(owner).approve(auctionFactory.address, 1);
      await auctionFactory.create(
        0,
        nftTest.address,
        1,
        token.address,
        startingBid,
        currentTime,
        currentTime + 1000,
        10
      );
      expect(await auctionFactory.getAuctionId()).to.equal(1);
      const auctionAddress = await auctionFactory.getAuctionByUser(
        owner.address
      );
      // console.log(auctionAddress);
      expect(
        await auctionFactory.checkAuctionOfUser(
          owner.address,
          auctionAddress[0]
        )
      ).to.be.true;

      await nftTest.connect(user1).approve(auctionFactory.address, 2);
      await auctionFactory
        .connect(user1)
        .create(
          1,
          nftTest.address,
          2,
          token.address,
          startingBid,
          currentTime,
          currentTime + 1000,
          100
        );
      expect(await auctionFactory.getAuctionId()).to.equal(2);
      const aucA = await auctionFactory.getAuctionByUser(user1.address);
      // console.log(aucA);
      expect(await auctionFactory.checkAuctionOfUser(user1.address, aucA[0])).to
        .be.true;
    });
  });

  describe("setDutchTemplate function:", async () => {
    it("should revert when zero address: ", async () => {
      await expect(
        auctionFactory.setDutchTemplate(ZERO_ADDRESS)
      ).to.be.revertedWith("InvalidAddress()");
    });
    it("should revert when caller is not an admin: ", async () => {
      await expect(
        auctionFactory.connect(user1).setDutchTemplate(user2.address)
      ).to.be.revertedWith("CallerIsNotOwnerOrAdmin()");
    });
    it("should setDutchTemplate success: ", async () => {
      await auctionFactory.setDutchTemplate(user2.address);
      expect(await auctionFactory.dutchTemplate()).to.equal(user2.address);
    });
  });

  describe("setEnglishAuction function:", async () => {
    it("should revert when zero address: ", async () => {
      await expect(
        auctionFactory.setEnglishAuction(ZERO_ADDRESS)
      ).to.be.revertedWith("InvalidAddress()");
    });
    it("should revert when caller is not an admin: ", async () => {
      await expect(
        auctionFactory.connect(user1).setEnglishAuction(user2.address)
      ).to.be.revertedWith("CallerIsNotOwnerOrAdmin()");
    });
    it("should setEnglishAuction success: ", async () => {
      await auctionFactory.setEnglishAuction(user2.address);
      expect(await auctionFactory.englishTemplate()).to.equal(user2.address);
    });
  });

  // describe("checkAuctionOfUser function:", async () => {
  //   it("should revert when bid before start time: ", async () => {});
  // });

  // describe("getAuctionByUser function:", async () => {
  //   it("should revert when bid before start time: ", async () => {});
  // });

  // describe("getAuctionId function:", async () => {
  //   it("should revert when bid before start time: ", async () => {});
  // });
});
