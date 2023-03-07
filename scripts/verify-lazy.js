const hre = require("hardhat");
const contracts = require("../contracts-verify.json");

async function main() {
  // Verify contracts
  console.log(
    "========================================================================================="
  );
  console.log("VERIFY CONTRACTS");
  console.log(
    "========================================================================================="
  );

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
      address: contracts.marketplace,
      contract: "contracts/Marketplace/Marketplace.sol:Marketplace",
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
