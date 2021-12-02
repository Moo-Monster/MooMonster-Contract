const hre = require("hardhat");
const fs = require("fs");

const chainId = hre.network.config.chainId;
const tgeTimestamp = miscs.tgeTimestamp[chainId];

async function main() {
  console.log(chainId);

  const MooVesting = await hre.ethers.getContractFactory("MOOVesting");

  const args = {
    mooAddress: "",
    merkleRoot: "",
    tgeTimestamp: 0,
  };

  const vesting = await MooVesting.deploy(
    args.mooAddress,
    args.merkleRoot,
    args.tgeTimestamp
  );
  await vesting.deployed();
  console.log("Moo Vesting deployed to:", vesting.address);


  if (chainId != "31337") {
    await hre.run("verify:verify", {
      address: vesting.address,
      constructorArguments: args,
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
