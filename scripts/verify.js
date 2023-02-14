const hre = require("hardhat");
const contracts = require("../contracts.json");

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
      address: contracts.lazyMint,
      constructorArguments: ["0xfEF202dcBc3e897f2c53Ad6451F6385753367201"],
    });
  } catch (e) {
    console.log(e.message);
  }

  //   for (key in contracts)
  // await hre
  //   .run("verify:verify", {
  //     address: contracts[key],
  //     arguments: ["0xfef202dcbc3e897f2c53ad6451f6385753367201"],
  //   })
  //   .catch(console.log);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
