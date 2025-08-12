const { ethers, run } = require("hardhat");

const tokenAddress =  process.env.KIGU_ADDRESS;
const treasuryAddress =  process.env.TREASURY_ADDRESS;

console.log("VARS", tokenAddress, treasuryAddress);
if (!tokenAddress || !treasuryAddress) {
  console.error("environment variables not set");
  process.exit(1);
}

async function verify(name, address, args = []) {
  try {
    await run("verify:verify", {
      address,
      constructorArguments: args,
    });
    console.log(`✅ Verified ${name} at ${address}`);
  } catch (err) {
    if (err.message.toLowerCase().includes("already verified")) {
      console.log(`ℹ️ ${name} already verified.`);
    } else {
      console.error(`❌ Verification failed for ${name}:`, err.message);
    }
  }
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("🚀 Deploying from:", deployer.address);

  // 1. Deploy PermissionsManager (or whatever the contract is)
  const PermissionsManager = await ethers.getContractFactory("PermissionsManager");
  const permissions = await PermissionsManager.deploy();
  await permissions.deployed();
  console.log("✅ PermissionsManager deployed at:", permissions.address);

  // 2. Deploy SCSeasonRewards
  const SCSeasonRewards = await ethers.getContractFactory("SCSeasonRewards");

  const seasonRewards = await SCSeasonRewards.deploy(
    permissions.address, // permissions_
    tokenAddress,        // token_
    treasuryAddress, // treasury_
    ethers.constants.AddressZero, // access_pass_
    ethers.constants.AddressZero  // staking_pool_
  );

  await seasonRewards.deployed();
  console.log("✅ SCSeasonRewards deployed at:", seasonRewards.address);

  // 3. Verify both
  await verify("PermissionsManager", permissions.address);
  await verify("SCSeasonRewards", seasonRewards.address, [
    permissions.address,
    tokenAddress,
    ethers.constants.AddressZero,
    ethers.constants.AddressZero,
    ethers.constants.AddressZero,
  ]);
}

main().then(() => {
  console.log("🎉 All done");
}).catch(err => {
  console.error("❌ Error:", err);
  process.exit(1);
});
