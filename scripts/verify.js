const hre = require("hardhat");
const contracts = require("../contracts-verify.json");

async function main() {
  try {
    await hre.run("verify:verify", {
      address: contracts.admin,
      contract: "contracts/Admin.sol:Admin",
    });
  } catch (err) {
    console.log("err :>> ", err);
  }
  try {
    await hre.run("verify:verify", {
      address: contracts.treasury,
      contract: "contracts/Treasury.sol:Treasury",
    });
  } catch (err) {
    console.log("err :>> ", err);
  }
  try {
    await hre.run("verify:verify", {
      address: contracts.usd,
      contract: "contracts/Token/CMCG.sol:CMCG",
    });
  } catch (err) {
    console.log("err :>> ", err);
  }

  try {
    await hre.run("verify:verify", {
      address: contracts.cmcg,
      constructorArguments: [
        "CMC Global Token",
        "CMCG",
        process.env.TOTAL_SUPPLY,
        contracts.treasury,
      ],
    });
  } catch (err) {
    console.log("err :>> ", err);
  }

  try {
    await hre.run("verify:verify", {
      address: contracts.tokenMintERC721,
      contract: "contracts/Token/TokenMintERC721.sol:TokenMintERC721",
    });
  } catch (err) {
    console.log("err :>> ", err);
  }

  try {
    await hre.run("verify:verify", {
      address: contracts.tokenMintERC1155,
      contract: "contracts/Token/TokenMintERC1155.sol:TokenMintERC1155",
    });
  } catch (err) {
    console.log("err :>> ", err);
  }

  try {
    await hre.run("verify:verify", {
      address: contracts.mtvsManager,
      contract: "contracts/Marketplace/NFTManager.sol:NFTManager",
    });
  } catch (err) {
    console.log("err :>> ", err);
  }

  try {
    await hre.run("verify:verify", {
      address: contracts.mkpManager,
      contract: "contracts/Marketplace/Marketplace.sol:Marketplace",
    });
  } catch (err) {
    console.log("err :>> ", err);
  }

  try {
    await hre.run("verify:verify", {
      address: contracts.staking,
      contract: "contracts/StakingPool/StakingPool.sol:StakingPool",
    });
  } catch (err) {
    console.log("err :>> ", err);
  }

  try {
    await hre.run("verify:verify", {
      address: contracts.poolFactory,
      contract: "contracts/StakingPool/PoolFactory.sol:PoolFactory",
    });
  } catch (err) {
    console.log("err :>> ", err);
  }
  try {
    await hre.run("verify:verify", {
      address: contracts.poolFactory,
      contract: "contracts/Collection/CollectionFactory.sol:CollectionFactory",
    });
  } catch (err) {
    console.log("err :>> ", err);
  }
  try {
    await hre.run("verify:verify", {
      address: contracts.tokenERC721,
      contract: "contracts/Collection/TokenERC721.sol:TokenERC721",
    });
  } catch (err) {
    console.log("err :>> ", err);
  }
  try {
    await hre.run("verify:verify", {
      address: contracts.tokenERC1155,
      contract: "contracts/Collection/TokenERC1155.sol:TokenERC1155",
    });
  } catch (err) {
    console.log("err :>> ", err);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
