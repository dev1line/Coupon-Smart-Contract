const { expect } = require("chai");
const { upgrades, ethers } = require("hardhat");
const { AddressZero } = ethers.constants;

const BATCH_URIS = ["this_uri", "this_uri_1", "this_uri_2"];

describe("TokenMintERC721", () => {
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

    MkpManager = await ethers.getContractFactory("Marketplace");
    mkpManager = await upgrades.deployProxy(MkpManager, [admin.address]);
  });

  describe("Deployment", async () => {
    it("Should revert when invalid admin contract address", async () => {
      await expect(
        upgrades.deployProxy(TokenMintERC721, [
          "CMC Global NFT",
          "nCMCG",
          AddressZero,
        ])
      ).to.revertedWith(`InValidAdminContract("${AddressZero}")`);

      await expect(
        upgrades.deployProxy(TokenMintERC721, [
          "CMC Global NFT",
          "nCMCG",
          user1.address,
        ])
      ).to.reverted;

      await expect(
        upgrades.deployProxy(TokenMintERC721, [
          "CMC Global NFT",
          "nCMCG",
          treasury.address,
        ])
      ).to.reverted;
    });

    it("Check name, symbol and default state", async () => {
      const name = await tokenMintERC721.name();
      const symbol = await tokenMintERC721.symbol();
      expect(name).to.equal("CMC Global NFT");
      expect(symbol).to.equal("nCMCG");

      // const royaltiesInfo = await tokenMintERC721.royaltyInfo(0, 10000);
      // expect(royaltiesInfo[0]).to.equal(treasury.address.toString());
      // expect(royaltiesInfo[1].toString()).to.equal("250");
    });

    it("Check tokenURI", async () => {
      const URI = "this_is_uri_1.json";
      await tokenMintERC721.mint(mkpManager.address, URI);

      const newURI = await tokenMintERC721.tokenURI(1);

      expect(newURI).to.equal(URI);
    });
  });

  describe("tokenURI function", async () => {
    it("should revert when invalid tokenID params", async () => {
      await expect(tokenMintERC721.tokenURI(2)).to.be.revertedWith(
        "URIQueryNonExistToken()"
      );
    });
  });

  describe("setTokenURI function", async () => {
    it("should set token URI successful", async () => {
      const URI = "this_is_uri_1.json";
      await tokenMintERC721.mint(mkpManager.address, URI);

      const newURI = await tokenMintERC721.tokenURI(1);
      await tokenMintERC721.mint(mkpManager.address, newURI);
      expect(newURI).to.equal(URI);
      await tokenMintERC721.setTokenURI("new_uri.json", 1);
      expect(await tokenMintERC721.tokenURI(1)).to.equal("new_uri.json");
      await tokenMintERC721.setTokenURI("new_uri_others.json", 2);
      expect(await tokenMintERC721.tokenURI(2)).to.equal("new_uri_others.json");
    });
  });

  describe("getTokenCounter function", async () => {
    it("should getTokenCounter", async () => {
      const URI = "this_is_uri_1.json";
      await tokenMintERC721.mint(mkpManager.address, URI);
      expect(await tokenMintERC721.getTokenCounter()).to.equal(1);

      const newURI = await tokenMintERC721.tokenURI(1);
      await tokenMintERC721.mint(mkpManager.address, newURI);
      expect(await tokenMintERC721.getTokenCounter()).to.equal(2);
    });
  });

  describe("mint function", async () => {
    it("should revert when caller is not an owner or admin", async () => {
      await expect(
        tokenMintERC721.connect(user1).mint(mkpManager.address, "this_uri")
      ).to.be.revertedWith("CallerIsNotOwnerOrAdmin()");
    });

    it("should revert when receiver address equal to zero address", async () => {
      await expect(
        tokenMintERC721.mint(AddressZero, "this_uri")
      ).to.be.revertedWith("InvalidAddress()");
    });
    it("should mint success", async () => {
      await tokenMintERC721.mint(mkpManager.address, "this_uri");
      expect(await tokenMintERC721.balanceOf(mkpManager.address)).to.equal(1);

      // const royaltiesInfo = await tokenMintERC721.royaltyInfo(1, 10000);
      // expect(royaltiesInfo[0]).to.equal(treasury.address.toString());
      // expect(royaltiesInfo[1].toString()).to.equal("250");
    });
  });

  describe("mintBatch", async () => {
    it("should revert when caller is not an owner or admin", async () => {
      await expect(
        tokenMintERC721.connect(user1).mintBatch(mkpManager.address, BATCH_URIS)
      ).to.be.revertedWith("CallerIsNotOwnerOrAdmin()");
    });

    it("should revert when receiver address equal to zero addres", async () => {
      await expect(
        tokenMintERC721.mintBatch(AddressZero, BATCH_URIS)
      ).to.be.revertedWith("InvalidAddress()");
    });

    it("should revert when amount of tokens is exceeded", async () => {
      await expect(
        tokenMintERC721.mintBatch(
          mkpManager.address,
          Array(101).fill("this_uri")
        )
      ).to.be.revertedWith("ExceedAmount()");
    });

    it("should mint success", async () => {
      await tokenMintERC721.mintBatch(mkpManager.address, BATCH_URIS);
      expect(await tokenMintERC721.balanceOf(mkpManager.address)).to.equal(3);

      // for (let i = 0; i < BATCH_URIS.length; i++) {
      //   const tokenId = i + 1;
      //   const royaltiesInfo = await tokenMintERC721.royaltyInfo(tokenId, 10000);
      //   expect(royaltiesInfo[0]).to.equal(treasury.address.toString());
      //   expect(royaltiesInfo[1].toString()).to.equal("250");
      // }
    });
  });

  describe("mintWithRoyalties", async () => {
    it("should revert when caller is not an owner or admin", async () => {
      await expect(
        tokenMintERC721
          .connect(user1)
          .mintWithRoyalties(mkpManager.address, "this_uri", 250)
      ).to.be.revertedWith("CallerIsNotOwnerOrAdmin()");
    });

    it("should revert when receiver address equal to zero address", async () => {
      await expect(
        tokenMintERC721.mintWithRoyalties(AddressZero, "this_uri", 250)
      ).to.be.revertedWith("InvalidAddress()");
    });

    it("should revert when fee Numerator equal to zero", async () => {
      await expect(
        tokenMintERC721.mintWithRoyalties(mkpManager.address, "this_uri", 0)
      ).to.be.revertedWith("InvalidAmount()");
    });

    it("should mintWithRoyalties success", async () => {
      await tokenMintERC721.mintWithRoyalties(
        mkpManager.address,
        "this_uri",
        250
      );
      expect(await tokenMintERC721.balanceOf(mkpManager.address)).to.equal(1);

      // const royaltiesInfo = await tokenMintERC721.royaltyInfo(1, 10000);
      // expect(royaltiesInfo[0]).to.equal(treasury.address.toString());
      // expect(royaltiesInfo[1].toString()).to.equal("250");
    });
  });

  describe("mintBatchWithRoyalties", async () => {
    it("should revert when caller is not an owner or admin", async () => {
      await expect(
        tokenMintERC721
          .connect(user1)
          .mintBatchWithRoyalties(mkpManager.address, BATCH_URIS, 250)
      ).to.be.revertedWith("CallerIsNotOwnerOrAdmin()");
    });

    it("should revert when receiver address equal to zero addres", async () => {
      await expect(
        tokenMintERC721.mintBatchWithRoyalties(AddressZero, BATCH_URIS, 250)
      ).to.be.revertedWith("InvalidAddress()");
    });

    it("should revert when amount of tokens is exceeded", async () => {
      await expect(
        tokenMintERC721.mintBatchWithRoyalties(
          mkpManager.address,
          Array(101).fill("this_uri"),
          250
        )
      ).to.be.revertedWith("ExceedAmount()");
    });

    it("should revert when fee Numerator equal to zero", async () => {
      await expect(
        tokenMintERC721.mintBatchWithRoyalties(
          mkpManager.address,
          BATCH_URIS,
          0
        )
      ).to.be.revertedWith("InvalidAmount()");
    });

    it("should mint success", async () => {
      await tokenMintERC721.mintBatchWithRoyalties(
        mkpManager.address,
        BATCH_URIS,
        250
      );
      expect(await tokenMintERC721.balanceOf(mkpManager.address)).to.equal(3);

      // for (let i = 0; i < BATCH_URIS.length; i++) {
      //   const tokenId = i + 1;
      //   const royaltiesInfo = await tokenMintERC721.royaltyInfo(tokenId, 10000);
      //   expect(royaltiesInfo[0]).to.equal(treasury.address.toString());
      //   expect(royaltiesInfo[1].toString()).to.equal("250");
      // }
    });
  });

  describe("support interface function:", async () => {
    it("check support interface:", async () => {
      expect(await tokenMintERC721.supportsInterface("0x5b5e139f")).to.be.true;
    });
  });
});
