const { expect } = require("chai");
const { upgrades, ethers } = require("hardhat");
const { AddressZero } = ethers.constants;

const BATCH_URIS = ["this_uri", "this_uri_1", "this_uri_2"];

describe("TokenMintERC1155", () => {
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

    TokenMintERC1155 = await ethers.getContractFactory("TokenMintERC1155");
    tokenMintERC1155 = await upgrades.deployProxy(TokenMintERC1155, [
      admin.address,
    ]);

    MkpManager = await ethers.getContractFactory("Marketplace");
    mkpManager = await upgrades.deployProxy(MkpManager, [admin.address]);
  });

  describe("Deployment", async () => {
    it("Should revert when invalid admin contract address", async () => {
      await expect(
        upgrades.deployProxy(TokenMintERC1155, [AddressZero])
      ).to.revertedWith(`InValidAdminContract("${AddressZero}")`);
      await expect(upgrades.deployProxy(TokenMintERC1155, [user1.address])).to
        .reverted;
      await expect(upgrades.deployProxy(TokenMintERC1155, [treasury.address]))
        .to.reverted;
    });

    it("Check uri", async () => {
      const URI = "this_is_uri_1.json";
      await tokenMintERC1155.mint(mkpManager.address, 100, URI);

      const newURI = await tokenMintERC1155.uri(1);

      expect(newURI).to.equal(URI);
    });

    // it("Check royalties", async () => {
    //     let royaltiesInfo = await tokenMintERC1155.royaltyInfo(0, 10000);

    //     expect(royaltiesInfo[0]).to.equal(treasury.address.toString());
    //     expect(royaltiesInfo[1].toString()).to.equal("250");
    // });
  });

  describe("setURI function", async () => {
    it("should setURI", async () => {
      const URI = "this_is_uri_1.json";
      await tokenMintERC1155.mint(mkpManager.address, 100, URI);

      const newURI = await tokenMintERC1155.uri(1);

      expect(newURI).to.equal(URI);
      await tokenMintERC1155.setURI("new_uri.json", 1);
      expect(await tokenMintERC1155.uri(1)).to.equal("new_uri.json");

      await tokenMintERC1155.mint(mkpManager.address, 100, newURI);
      await tokenMintERC1155.setURI("new_uri_others.json", 2);
      expect(await tokenMintERC1155.uri(2)).to.equal("new_uri_others.json");
    });
  });

  describe("getTokenCounter function", async () => {
    it("should getTokenCounter", async () => {
      const URI = "this_is_uri_1.json";
      await tokenMintERC1155.mint(mkpManager.address, 100, URI);
      expect(await tokenMintERC1155.getTokenCounter()).to.equal(1);

      const newURI = await tokenMintERC1155.uri(1);
      await tokenMintERC1155.mint(mkpManager.address, 100, newURI);
      expect(await tokenMintERC1155.getTokenCounter()).to.equal(2);

      const uri_ = await tokenMintERC1155.uri(1);
      expect(uri_).to.equal(URI);
      await tokenMintERC1155.mint(
        mkpManager.address,
        100,
        "this_is_uri_others.json"
      );
      expect(await tokenMintERC1155.getTokenCounter()).to.equal(3);
    });
  });

  describe("mint function", async () => {
    it("should revert when caller is not owner", async () => {
      await expect(
        tokenMintERC1155
          .connect(user1)
          .mint(mkpManager.address, 100, "this_uri")
      ).to.be.revertedWith("CallerIsNotOwnerOrAdmin()");
    });
    it("should revert when receiver address equal to zero address", async () => {
      await expect(
        tokenMintERC1155.mint(AddressZero, 100, "this_uri")
      ).to.be.revertedWith("InvalidAddress()");
    });
    it("should revert when amount equal to zero address", async () => {
      await expect(
        tokenMintERC1155.mint(mkpManager.address, 0, "this_uri")
      ).to.be.revertedWith("InvalidAmount()");
    });
    it("should mint success", async () => {
      await tokenMintERC1155.mint(mkpManager.address, 100, "this_uri");
      expect(await tokenMintERC1155.balanceOf(mkpManager.address, 1)).to.equal(
        100
      );

      // const royaltiesInfo = await tokenMintERC1155.royaltyInfo(1, 10000);
      // expect(royaltiesInfo[0]).to.equal(treasury.address.toString());
      // expect(royaltiesInfo[1].toString()).to.equal("250");
    });
  });

  describe("mintWithRoyalties function", async () => {
    it("should revert when caller is not owner", async () => {
      await expect(
        tokenMintERC1155
          .connect(user1)
          .mintWithRoyalties(mkpManager.address, 100, "this_uri", 250)
      ).to.be.revertedWith("CallerIsNotOwnerOrAdmin()");
    });
    it("should revert when receiver address equal to zero address", async () => {
      await expect(
        tokenMintERC1155.mintWithRoyalties(AddressZero, 100, "this_uri", 250)
      ).to.be.revertedWith("InvalidAddress()");
    });
    it("should revert when amount equal to zero address", async () => {
      await expect(
        tokenMintERC1155.mintWithRoyalties(
          mkpManager.address,
          0,
          "this_uri",
          250
        )
      ).to.be.revertedWith("InvalidAmount()");
    });
    it("should revert when fee equal to zero", async () => {
      await expect(
        tokenMintERC1155.mintWithRoyalties(
          mkpManager.address,
          100,
          "this_uri",
          0
        )
      ).to.be.revertedWith("InvalidAmount()");
    });
    it("should mint success", async () => {
      await tokenMintERC1155.mintWithRoyalties(
        mkpManager.address,
        100,
        "this_uri",
        250
      );
      expect(await tokenMintERC1155.balanceOf(mkpManager.address, 1)).to.equal(
        100
      );

      // const royaltiesInfo = await tokenMintERC1155.royaltyInfo(1, 10000);
      // expect(royaltiesInfo[0]).to.equal(treasury.address.toString());
      // expect(royaltiesInfo[1].toString()).to.equal("250");
    });
  });

  describe("batch mint function", async () => {
    it("should revert when caller is not an owner or admin", async () => {
      await expect(
        tokenMintERC1155
          .connect(user1)
          .mintBatch(mkpManager.address, [101, 102, 103], BATCH_URIS)
      ).to.be.revertedWith("CallerIsNotOwnerOrAdmin()");
    });

    it("should revert when amount length not equal to uris length", async () => {
      await expect(
        tokenMintERC1155.mintBatch(
          mkpManager.address,
          [10, 11, 12, 13],
          BATCH_URIS
        )
      ).to.be.revertedWith("InvalidLength()");
    });

    it("should revert when receiver address equal to zero address", async () => {
      await expect(
        tokenMintERC1155.mintBatch(AddressZero, [10, 11, 12], BATCH_URIS)
      ).to.be.revertedWith("InvalidAddress()");
    });

    it("should revert when amount equal to zero address", async () => {
      await expect(
        tokenMintERC1155.mintBatch(
          mkpManager.address,
          [0, 100, 100],
          BATCH_URIS
        )
      ).to.be.revertedWith("InvalidAmount()");
    });

    it("should mint success", async () => {
      expect(
        await tokenMintERC1155.mintBatch(
          mkpManager.address,
          [10, 11, 12],
          BATCH_URIS
        )
      )
        .to.emit(tokenMintERC1155, "MintedBatch")
        .withArgs([10, 11, 12], mkpManager.address);
      expect(await tokenMintERC1155.balanceOf(mkpManager.address, 1)).to.equal(
        10
      );
      expect(await tokenMintERC1155.balanceOf(mkpManager.address, 2)).to.equal(
        11
      );
      expect(await tokenMintERC1155.balanceOf(mkpManager.address, 3)).to.equal(
        12
      );
      expect(await tokenMintERC1155.getTokenCounter()).to.equal(3);

      expect(await tokenMintERC1155.uri(1)).to.equal(BATCH_URIS[0]);
      expect(await tokenMintERC1155.uri(2)).to.equal(BATCH_URIS[1]);
      expect(await tokenMintERC1155.uri(3)).to.equal(BATCH_URIS[2]);
      // for (let i = 0; i < BATCH_URIS.length; i++) {
      //     const tokenId = i + 1;
      //     const royaltiesInfo = await tokenMintERC1155.royaltyInfo(tokenId, 10000);
      //     expect(royaltiesInfo[0]).to.equal(treasury.address.toString());
      //     expect(royaltiesInfo[1].toString()).to.equal("250");
      // }
    });
  });

  describe("mintBatchWithRoyalties function", async () => {
    it("should revert when caller is not an owner or admin", async () => {
      await expect(
        tokenMintERC1155
          .connect(user1)
          .mintBatchWithRoyalties(
            mkpManager.address,
            [101, 102, 103],
            BATCH_URIS,
            250
          )
      ).to.be.revertedWith("CallerIsNotOwnerOrAdmin()");
    });

    it("should revert when amount length not equal to uris length", async () => {
      await expect(
        tokenMintERC1155.mintBatchWithRoyalties(
          mkpManager.address,
          [10, 11, 12, 13],
          BATCH_URIS,
          250
        )
      ).to.be.revertedWith("InvalidLength()");
    });

    it("should revert when receiver address equal to zero address", async () => {
      await expect(
        tokenMintERC1155.mintBatchWithRoyalties(
          AddressZero,
          [10, 11, 12],
          BATCH_URIS,
          250
        )
      ).to.be.revertedWith("InvalidAddress()");
    });

    it("should revert when amount equal to zero address", async () => {
      await expect(
        tokenMintERC1155.mintBatchWithRoyalties(
          mkpManager.address,
          [0, 100, 100],
          BATCH_URIS,
          250
        )
      ).to.be.revertedWith("InvalidAmount()");
    });

    it("should revert when fee equal to zero", async () => {
      await expect(
        tokenMintERC1155.mintBatchWithRoyalties(
          mkpManager.address,
          [100, 100, 100],
          BATCH_URIS,
          0
        )
      ).to.be.revertedWith("InvalidAmount()");
    });

    it("should mint success", async () => {
      expect(
        await tokenMintERC1155.mintBatchWithRoyalties(
          mkpManager.address,
          [10, 11, 12],
          BATCH_URIS,
          250
        )
      )
        .to.emit(tokenMintERC1155, "MintedBatch")
        .withArgs([10, 11, 12], mkpManager.address, BATCH_URIS, 250);
      expect(await tokenMintERC1155.balanceOf(mkpManager.address, 1)).to.equal(
        10
      );
      expect(await tokenMintERC1155.balanceOf(mkpManager.address, 2)).to.equal(
        11
      );
      expect(await tokenMintERC1155.balanceOf(mkpManager.address, 3)).to.equal(
        12
      );
      expect(await tokenMintERC1155.getTokenCounter()).to.equal(3);

      expect(await tokenMintERC1155.uri(1)).to.equal(BATCH_URIS[0]);
      expect(await tokenMintERC1155.uri(2)).to.equal(BATCH_URIS[1]);
      expect(await tokenMintERC1155.uri(3)).to.equal(BATCH_URIS[2]);
      // for (let i = 0; i < BATCH_URIS.length; i++) {
      //     const tokenId = i + 1;
      //     const royaltiesInfo = await tokenMintERC1155.royaltyInfo(tokenId, 10000);
      //     expect(royaltiesInfo[0]).to.equal(treasury.address.toString());
      //     expect(royaltiesInfo[1].toString()).to.equal("250");
      // }
    });
  });

  describe("support interface function:", async () => {
    it("check support interface:", async () => {
      expect(await tokenMintERC1155.supportsInterface("0x5b5e139f")).to.be
        .false;
      // 1155 interfaceid
      expect(await tokenMintERC1155.supportsInterface("0xd9b67a26")).to.be.true;
    });
  });
});
