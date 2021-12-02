const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const chainId = hre.network.config.chainId;

  const MooMonsterToken = await hre.ethers.getContractFactory(
    "MooMonsterToken"
  );
  const token = await MooMonsterToken.deploy();
  await token.deployed();
  console.log("MooMonster Token deployed to:", token.address);

  if (chainId != "31337") {
    await hre.run("verify:verify", {
      address: token.address,
      constructorArguments: [],
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
