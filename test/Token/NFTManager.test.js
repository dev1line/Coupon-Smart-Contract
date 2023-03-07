const { expect } = require("chai");
const { upgrades, ethers } = require("hardhat");
const { AddressZero } = ethers.constants;

const BATCH_URIS = ["this_uri", "this_uri_1", "this_uri_2"];

describe("NFT Manager", () => {
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

    TokenMintERC721 = await ethers.getContractFactory("TokenMintERC721");
    tokenMintERC721 = await upgrades.deployProxy(TokenMintERC721, [
      "CMC Global NFT",
      "nCMCG",
      admin.address,
    ]);

    TokenMintERC1155 = await ethers.getContractFactory("TokenMintERC1155");
    tokenMintERC1155 = await upgrades.deployProxy(TokenMintERC1155, [
      admin.address,
    ]);

    MkpManager = await ethers.getContractFactory("Marketplace");
    mkpManager = await upgrades.deployProxy(MkpManager, [admin.address]);

    NFTManager = await ethers.getContractFactory("NFTManager");
    nftManager = await upgrades.deployProxy(NFTManager, [
      tokenMintERC721.address,
      tokenMintERC1155.address,
      admin.address,
    ]);
    await admin.setAdmin(nftManager.address, true);
  });

  describe("Deployment", async () => {
    it("Check name, symbol and default state", async () => {
      const _tokenMintERC721 = await nftManager.tokenMintERC721();
      const _tokenMintERC1155 = await nftManager.tokenMintERC1155();
      expect(_tokenMintERC721).to.equal(tokenMintERC721.address);
      expect(_tokenMintERC1155).to.equal(tokenMintERC1155.address);
    });
  });

  describe("createNFT function", async () => {
    it("should revert when contract is paused", async () => {
      await nftManager.setPause(true);
      await expect(nftManager.createNFT(0, 1, "this_uri")).to.be.revertedWith(
        "Pausable: paused"
      );

      await expect(nftManager.createNFT(1, 2, "this_uri")).to.be.revertedWith(
        "Pausable: paused"
      );
    });

    it("should revert when amount equal zero", async () => {
      await expect(nftManager.createNFT(0, 0, "this_uri")).to.be.revertedWith(
        "InvalidAmount()"
      );

      await expect(nftManager.createNFT(1, 0, "this_uri")).to.be.revertedWith(
        "InvalidAmount()"
      );
    });

    it("should create token erc721", async () => {
      expect(await nftManager.createNFT(0, 1, "this_uri"))
        .to.emit(nftManager, "Created")
        .withArgs(tokenMintERC721.address, 1, owner.address, 1);
      expect(await tokenMintERC721.balanceOf(owner.address)).to.equal(1);
    });

    it("should create token erc1155", async () => {
      expect(await nftManager.createNFT(1, 2, "this_uri"))
        .to.emit(nftManager, "Created")
        .withArgs(tokenMintERC1155.address, 2, owner.address, 3);
      expect(await tokenMintERC1155.balanceOf(owner.address, 1)).to.equal(2);
    });
  });

  describe("batch create function", async () => {
    it("should revert when contract is paused", async () => {
      await nftManager.setPause(true);
      await expect(
        nftManager.createBatchNFT(
          0,
          [101, 102, 103],
          ["this_uri", "this_uri_1", "this_uri_2"]
        )
      ).to.be.revertedWith("Pausable: paused");

      await expect(
        nftManager.createBatchNFT(
          1,
          [101, 102, 103],
          ["this_uri", "this_uri_1", "this_uri_2"]
        )
      ).to.be.revertedWith("Pausable: paused");
    });

    it("should create token erc721", async () => {
      expect(
        await nftManager.createBatchNFT(
          0,
          [101, 102, 103],
          ["this_uri", "this_uri_1", "this_uri_2"]
        )
      )
        .to.emit(nftManager, "BatchCreated")
        .withArgs(0, [101, 102, 103], ["this_uri", "this_uri_1", "this_uri_2"]);
      expect(await tokenMintERC721.balanceOf(owner.address)).to.equal(3);
    });

    it("should create token erc1155", async () => {
      expect(
        await nftManager.createBatchNFT(
          1,
          [101, 102, 103],
          ["this_uri", "this_uri_1", "this_uri_2"]
        )
      )
        .to.emit(nftManager, "BatchCreated")
        .withArgs(1, [101, 102, 103], ["this_uri", "this_uri_1", "this_uri_2"]);

      expect(await tokenMintERC1155.balanceOf(owner.address, 1)).to.equal(101);
      expect(await tokenMintERC1155.balanceOf(owner.address, 2)).to.equal(102);
      expect(await tokenMintERC1155.balanceOf(owner.address, 3)).to.equal(103);
    });
  });

  describe("createBatchNFTWithRoyalties function", async () => {
    it("should revert when contract is paused", async () => {
      await nftManager.setPause(true);
      await expect(
        nftManager.createBatchNFTWithRoyalties(
          0,
          [101, 102, 103],
          ["this_uri", "this_uri_1", "this_uri_2"],
          250
        )
      ).to.be.revertedWith("Pausable: paused");

      await expect(
        nftManager.createBatchNFTWithRoyalties(
          1,
          [101, 102, 103],
          ["this_uri", "this_uri_1", "this_uri_2"],
          250
        )
      ).to.be.revertedWith("Pausable: paused");
    });

    it("should create token erc721", async () => {
      expect(
        await nftManager.createBatchNFTWithRoyalties(
          0,
          [101, 102, 103],
          ["this_uri", "this_uri_1", "this_uri_2"],
          250
        )
      )
        .to.emit(nftManager, "BatchCreated")
        .withArgs(
          0,
          [101, 102, 103],
          ["this_uri", "this_uri_1", "this_uri_2"],
          250
        );
      expect(await tokenMintERC721.balanceOf(owner.address)).to.equal(3);
    });

    it("should create token erc1155", async () => {
      expect(
        await nftManager.createBatchNFTWithRoyalties(
          1,
          [101, 102, 103],
          ["this_uri", "this_uri_1", "this_uri_2"],
          250
        )
      )
        .to.emit(nftManager, "BatchCreated")
        .withArgs(
          1,
          [101, 102, 103],
          ["this_uri", "this_uri_1", "this_uri_2"],
          250
        );

      expect(await tokenMintERC1155.balanceOf(owner.address, 1)).to.equal(101);
      expect(await tokenMintERC1155.balanceOf(owner.address, 2)).to.equal(102);
      expect(await tokenMintERC1155.balanceOf(owner.address, 3)).to.equal(103);
    });
  });
});
