const hre = require("hardhat");
const fs = require("fs");
const ethers = hre.ethers;
const upgrades = hre.upgrades;
async function main() {
  //Loading accounts
  const accounts = await ethers.getSigners();
  const addresses = accounts.map((item) => item.address);
  const owner = addresses[0];

  // Loading contract factory.
  const USD = await ethers.getContractFactory("USD");
  const CMCG = await ethers.getContractFactory("CMCG");
  const Treasury = await ethers.getContractFactory("Treasury");
  const Marketplace = await ethers.getContractFactory("Marketplace");
  const TokenMintERC721 = await ethers.getContractFactory("TokenMintERC721");
  const TokenMintERC1155 = await ethers.getContractFactory("TokenMintERC1155");
  const TokenERC721 = await ethers.getContractFactory("TokenERC721");
  const TokenERC1155 = await ethers.getContractFactory("TokenERC1155");

  const NFTManager = await ethers.getContractFactory("NFTManager");

  const CollectionFactory = await ethers.getContractFactory(
    "CollectionFactory"
  );

  const Staking = await ethers.getContractFactory("StakingPool");
  const PoolFactory = await ethers.getContractFactory("PoolFactory");

  // Deploy contracts
  console.log(
    "========================================================================================="
  );
  console.log("DEPLOY CONTRACTS");
  console.log(
    "========================================================================================="
  );

  const Admin = await ethers.getContractFactory("Admin");
  const admin = await upgrades.deployProxy(Admin, [owner]);
  await admin.deployed();
  console.log("admin deployed in:", admin.address);
  console.log(
    "========================================================================================="
  );
  const treasury = await upgrades.deployProxy(Treasury, [admin.address]);
  await treasury.deployed();

  console.log("treasury deployed in:", treasury.address);
  console.log(
    "========================================================================================="
  );
  const cmcg = await CMCG.deploy(
    "CMC Global Token",
    "CMCG",
    process.env.TOTAL_SUPPLY,
    treasury.address
  );
  await cmcg.deployed();

  console.log("cmcg deployed in:", cmcg.address);
  console.log(
    "========================================================================================="
  );

  const marketplace = await upgrades.deployProxy(Marketplace, [admin.address]);
  await marketplace.deployed();

  console.log("marketplace deployed in:", marketplace.address);
  console.log(
    "========================================================================================="
  );

  // Factory Pool
  const staking = await Staking.deploy();
  console.log("staking template deployed in:", staking.address);
  console.log(
    "========================================================================================="
  );
  const poolFactory = await upgrades.deployProxy(PoolFactory, [
    staking.address,
    admin.address,
  ]);
  await poolFactory.deployed();
  console.log("PoolFactory deployed in:", poolFactory.address);
  console.log(
    "========================================================================================="
  );
  const tx_pool30d = await poolFactory.create(
    cmcg.address,
    cmcg.address,
    marketplace.address,
    process.env.REWARD_RATE_30_DAY,
    process.env.POOL_DURATION_30_DAY,
    process.env.PANCAKE_ROUTER,
    process.env.BUSD_TOKEN,
    process.env.EACA_AGGREGATOR_BUSD_USD_TESTNET
  );

  await tx_pool30d.wait();
  let all = await poolFactory.getAllPool();
  console.log("Pool 30 days deployed", all[0]["poolAddress"]);
  console.log(
    "========================================================================================="
  );
  const tx_pool60d = await poolFactory.create(
    cmcg.address,
    cmcg.address,
    marketplace.address,
    process.env.REWARD_RATE_60_DAY,
    process.env.POOL_DURATION_60_DAY,
    process.env.PANCAKE_ROUTER,
    process.env.BUSD_TOKEN,
    process.env.EACA_AGGREGATOR_BUSD_USD_TESTNET
  );

  await tx_pool60d.wait();
  all = await poolFactory.getAllPool();
  console.log("Pool 60 days deployed", all[1]["poolAddress"]);
  console.log(
    "========================================================================================="
  );
  const tx_pool90d = await poolFactory.create(
    cmcg.address,
    cmcg.address,
    marketplace.address,
    process.env.REWARD_RATE_90_DAY,
    process.env.POOL_DURATION_90_DAY,
    process.env.PANCAKE_ROUTER,
    process.env.BUSD_TOKEN,
    process.env.EACA_AGGREGATOR_BUSD_USD_TESTNET
  );

  await tx_pool90d.wait();
  all = await poolFactory.getAllPool();
  console.log("Pool 90 days deployed", all[2]["poolAddress"]);
  console.log(
    "========================================================================================="
  );

  const usd = await upgrades.deployProxy(USD, [
    admin.address,
    "USD Token Test",
    "USD",
    process.env.TOTAL_SUPPLY,
    treasury.address,
  ]);
  await usd.deployed();
  console.log("usd deployed in:", usd.address);
  console.log(
    "========================================================================================="
  );
  // Set permitted token
  let tx = await admin.setPermittedPaymentToken(process.env.ZERO_ADDRESS, true);
  await tx.wait();
  tx = await admin.setPermittedPaymentToken(cmcg.address, true);
  await tx.wait();
  tx = await admin.setPermittedPaymentToken(usd.address, true);
  await tx.wait();

  const tokenMintERC721 = await upgrades.deployProxy(TokenMintERC721, [
    "NFT CMCG",
    "nCMCG",
    admin.address,
  ]);
  await tokenMintERC721.deployed();

  console.log("tokenMintERC721 deployed in:", tokenMintERC721.address);
  console.log(
    "========================================================================================="
  );

  const tokenMintERC1155 = await upgrades.deployProxy(TokenMintERC1155, [
    admin.address,
  ]);
  await tokenMintERC1155.deployed();

  console.log("tokenMintERC1155 deployed in:", tokenMintERC1155.address);
  console.log(
    "========================================================================================="
  );

  const tokenERC721 = await TokenERC721.deploy();
  console.log("TokenERC721 template deployed in:", tokenERC721.address);
  console.log(
    "========================================================================================="
  );
  const tokenERC1155 = await TokenERC1155.deploy();
  console.log("TokenERC1155 template deployed in:", tokenERC1155.address);
  console.log(
    "========================================================================================="
  );

  const collectionFactory = await upgrades.deployProxy(CollectionFactory, [
    tokenERC721.address,
    tokenERC1155.address,
    admin.address,
    admin.address,
  ]);

  await collectionFactory.deployed();
  console.log("CollectionFactory deployed in:", collectionFactory.address);
  console.log(
    "========================================================================================="
  );

  console.log("VERIFY ADDRESSES");
  console.log(
    "========================================================================================="
  );
  const adminVerify = await upgrades.erc1967.getImplementationAddress(
    admin.address
  );
  console.log("Admin verify deployed in:", adminVerify);
  console.log(
    "========================================================================================="
  );
  const treasuryVerify = await upgrades.erc1967.getImplementationAddress(
    treasury.address
  );
  console.log("treasuryVerify deployed in:", treasuryVerify);
  console.log(
    "========================================================================================="
  );
  const usdVerify = await upgrades.erc1967.getImplementationAddress(
    usd.address
  );
  console.log("usdVerify deployed in:", usdVerify);
  console.log(
    "========================================================================================="
  );

  const tokenMintERC721Verify = await upgrades.erc1967.getImplementationAddress(
    tokenMintERC721.address
  );
  console.log("tokenMintERC721Verify deployed in:", tokenMintERC721Verify);
  console.log(
    "========================================================================================="
  );
  const tokenMintERC1155Verify = await upgrades.erc1967.getImplementationAddress(
    tokenMintERC1155.address
  );
  console.log("tokenMintERC1155Verify deployed in:", tokenMintERC1155Verify);
  console.log(
    "========================================================================================="
  );
  const collectionFactoryVerify = await upgrades.erc1967.getImplementationAddress(
    collectionFactory.address
  );
  console.log("CollectionFactory verify deployed in:", collectionFactoryVerify);
  console.log(
    "========================================================================================="
  );

  const marketplaceVerify = await upgrades.erc1967.getImplementationAddress(
    marketplace.address
  );
  console.log("marketplaceVerify deployed in:", marketplaceVerify);
  console.log(
    "========================================================================================="
  );
  const poolFactoryVerify = await upgrades.erc1967.getImplementationAddress(
    poolFactory.address
  );
  console.log("poolFactoryVerify deployed in:", poolFactoryVerify);
  console.log(
    "========================================================================================="
  );

  const contractAddresses = {
    admin: admin.address,
    cmcg: cmcg.address,
    treasury: treasury.address,
    tokenMintERC721: tokenMintERC721.address,
    tokenMintERC1155: tokenMintERC1155.address,
    tokenERC721: tokenERC721.address,
    tokenERC1155: tokenERC1155.address,
    marketplace: marketplace.address,
    staking30d: all[0]["poolAddress"],
    staking60d: all[1]["poolAddress"],
    staking90d: all[2]["poolAddress"],
    staking: staking.address,
    poolFactory: poolFactory.address,
    collectionFactory: collectionFactory.address,
  };
  console.log("contract Address:", contractAddresses);
  await fs.writeFileSync("contracts.json", JSON.stringify(contractAddresses));

  const contractAddresses_verify = {
    admin: adminVerify,
    treasury: treasuryVerify,
    cmcg: cmcg.address,
    tokenMintERC721: tokenMintERC721Verify,
    tokenMintERC1155: tokenMintERC1155Verify,
    tokenERC721: tokenERC721.address,
    tokenERC1155: tokenERC1155.address,
    marketplace: marketplaceVerify,
    staking: staking.address,
    poolFactory: poolFactoryVerify,
    collectionFactory: collectionFactoryVerify,
  };

  await fs.writeFileSync(
    "contracts-verify.json",
    JSON.stringify(contractAddresses_verify)
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
