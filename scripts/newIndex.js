const { ethers, upgrades } = require("hardhat");

async function main() {
  const tokenAddress = "0x20324Ddb80da7F613D1312e9fE1E29F6dc83c6BE";

  const CliffLocker = await ethers.getContractFactory("SCLock");

  const proxy = await upgrades.deployProxy(CliffLocker, [tokenAddress], {
    initializer: "initialize",
  });

  await proxy.waitForDeployment();

  console.log("CliffLocker deployed to proxy at:", proxy.getAddress);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Deployment failed:", err);
    process.exit(1);
  });
