const fs = require("fs");
const { ethers, upgrades } = require("hardhat");

async function main() {
  const [account] = await ethers.getSigners();

  console.log(
    "====================================================================================="
  );
  console.log(`ACCOUNTS: ${account.address}`);
  console.log(
    "====================================================================================="
  );

  console.log(
    "====================================================================================="
  );
  console.log(`DEPLOYED CONTRACT ADDRESS TO:  ${hre.network.name}`);
  console.log(
    "====================================================================================="
  );

  const Admin = await ethers.getContractFactory("Admin");
  const admin = await upgrades.deployProxy(Admin, [account.address]);
  await admin.deployed();
  console.log("admin deployed in:", admin.address);
  const adminVerify = await upgrades.erc1967.getImplementationAddress(
    admin.address
  );
  console.log("Admin verify deployed in:", adminVerify);
  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await upgrades.deployProxy(Marketplace, [admin.address]);
  await marketplace.deployed();

  console.log(" marketplace deployed to:", marketplace.address);
  const marketplaceVerify = await upgrades.erc1967.getImplementationAddress(
    marketplace.address
  );
  console.log("marketplace verify deployed in:", marketplaceVerify);
  console.log(
    "====================================================================================="
  );

  // export deployed contracts to json (using for front-end)
  const contractAddresses = {
    admin: admin.address,
    marketplace: marketplace.address,
  };
  await fs.writeFileSync("contracts.json", JSON.stringify(contractAddresses));

  const contractAddresses_verify = {
    admin: adminVerify,
    marketplace: marketplaceVerify,
  };

  await fs.writeFileSync(
    "contracts-verify.json",
    JSON.stringify(contractAddresses_verify)
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
