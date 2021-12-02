const hre = require("hardhat");

async function main() {
  const chainId = hre.network.config.chainId;
  const mooAddress = ""
  const vestingAddress = ""

  const MooMonsterToken = await hre.ethers.getContractFactory(
    "MooMonsterToken"
  );
  const token = await MooMonsterToken.attach(
    mooAddress
  );

  const tx = await token.mint(vestingAddress);
  console.log(tx);
  const rcp = await tx.wait();
  console.log(rcp);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
