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

  const LazyMint = await ethers.getContractFactory("LazyNFT");
  const lazyMint = await LazyMint.deploy(
    "0xfEF202dcBc3e897f2c53Ad6451F6385753367201"
  );
  await lazyMint.deployed();

  console.log(" lazyMint deployed to:", lazyMint.address);
  console.log(
    "====================================================================================="
  );

  // export deployed contracts to json (using for front-end)
  const contractAddresses = {
    lazyMint: lazyMint.address,
  };
  await fs.writeFileSync("contracts.json", JSON.stringify(contractAddresses));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
