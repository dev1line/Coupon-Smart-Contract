const { expect } = require("chai");
const { upgrades, ethers } = require("hardhat");
const { parseEther } = ethers.utils;
const { AddressZero } = ethers.constants;

const TOTAL_SUPPLY = parseEther("1000000000000");
const TOKEN_0_1 = parseEther("0.1");

describe("Admin", () => {
  beforeEach(async () => {
    const accounts = await ethers.getSigners();
    owner = accounts[0];
    user1 = accounts[1];
    user2 = accounts[2];
    user3 = accounts[3];

    Admin = await ethers.getContractFactory("Admin");
    admin = await upgrades.deployProxy(Admin, [owner.address]);

    Treasury = await ethers.getContractFactory("Treasury");
    treasury = await upgrades.deployProxy(Treasury, [admin.address]);

    Token = await ethers.getContractFactory("CMCG");
    token = await Token.deploy(
      "CMC Global Token",
      "MTVS",
      TOTAL_SUPPLY,
      treasury.address
    );

    TokenERC721 = await ethers.getContractFactory("TokenERC721");
    tokenERC721 = await upgrades.deployProxy(TokenERC721, [
      owner.address,
      "NFT Marketplace",
      "nCMCG",
      100,
      owner.address,
      10000,
    ]);

    await admin.setPermittedPaymentToken(token.address, true);
    await admin.setPermittedPaymentToken(AddressZero, true);
  });

  describe("Deployment", async () => {
    it("should revert when owner is zero address", async () => {
      await expect(
        upgrades.deployProxy(Admin, [AddressZero])
      ).to.be.revertedWith(`InvalidWallet("${AddressZero}")`);
    });

    it("should initialize successful", async () => {
      admin = await upgrades.deployProxy(Admin, [user1.address]);
      expect(await admin.owner()).to.equal(user1.address);
    });
  });

  describe("setAdmin", async () => {
    it("should revert when caller is not owner", async () => {
      await expect(
        admin.connect(user1).setAdmin(user2.address, true)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should revert when invalid wallet", async () => {
      await expect(admin.setAdmin(AddressZero, true)).to.revertedWith(
        "InvalidAddress()"
      );
    });

    it("should set admin successful", async () => {
      await admin.setAdmin(user2.address, true);
      expect(await admin.isAdmin(user2.address)).to.be.true;

      await admin.setAdmin(user1.address, false);
      expect(await admin.isAdmin(user1.address)).to.be.false;

      await admin.setAdmin(user2.address, false);
      expect(await admin.isAdmin(user2.address)).to.be.false;
    });
  });

  describe("setPermittedPaymentToken", async () => {
    it("should revert when caller is not an owner or admin", async () => {
      await expect(
        admin.connect(user1).setPermittedPaymentToken(token.address, true)
      ).to.be.revertedWith("CallerIsNotOwnerOrAdmin()");
    });

    it("should set or remove payment token successful", async () => {
      await admin.connect(owner).setPermittedPaymentToken(token.address, true);
      expect(await admin.isPermittedPaymentToken(token.address)).to.be.true;

      await admin.connect(owner).setPermittedPaymentToken(token.address, false);
      expect(await admin.isPermittedPaymentToken(token.address)).to.be.false;

      await admin
        .connect(owner)
        .setPermittedPaymentToken(tokenERC721.address, false);
      expect(await admin.isPermittedPaymentToken(tokenERC721.address)).to.be
        .false;
    });
  });

  describe("setPermittedNFT", async () => {
    it("should revert when caller is not an owner or admin", async () => {
      await expect(
        admin.connect(user1).setPermittedNFT(tokenERC721.address, true)
      ).to.be.revertedWith("CallerIsNotOwnerOrAdmin()");
    });

    it("should set or remove an NFT successful", async () => {
      await admin.connect(owner).setPermittedNFT(tokenERC721.address, true);
      expect(await admin.isPermittedNFT(tokenERC721.address)).to.be.true;

      await admin.connect(owner).setPermittedNFT(tokenERC721.address, false);
      expect(await admin.isPermittedNFT(tokenERC721.address)).to.be.false;

      await admin.connect(owner).setPermittedNFT(token.address, false);
      expect(await admin.isPermittedNFT(token.address)).to.be.false;
    });
  });

  describe("setTreasury", async () => {
    it("should revert when caller is not an owner or admin", async () => {
      await expect(
        admin.connect(user1).setTreasury(user1.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("setTreasury successfully", async () => {
      await admin.connect(owner).setTreasury(user1.address);
      expect(await admin.treasury()).to.equal(user1.address);

      await admin.connect(owner).setTreasury(treasury.address);
      expect(await admin.treasury()).to.equal(treasury.address);
    });
  });

  describe("isAdmin", async () => {
    it("should return admin status correctly", async () => {
      await admin.setAdmin(user1.address, true);
      expect(await admin.isAdmin(user1.address)).to.be.true;
      expect(await admin.isAdmin(owner.address)).to.be.true;
      expect(await admin.isAdmin(user2.address)).to.be.false;
    });
  });
});
