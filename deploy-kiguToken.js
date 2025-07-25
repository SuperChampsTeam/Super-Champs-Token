const { ethers, upgrades, run } = require("hardhat");
const { fetchAbi } = require('./abi-fetcher.js');
const fs = require('fs');

const dirPath = './generated';

const firstAddress = "";
const secondAddress = "";
const thirdAddress = "";
const fourthAddress = "";
const minterAddress = "";
const multiSigAddress = "";

const wallets = [
  firstAddress,
  secondAddress,
  thirdAddress,
  fourthAddress
];
const percents = [6667, 1333, 1333, 667];
const decay = 3;

const verifyContract = async (contractName, contractAddress, constructorArgs = []) => {
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: constructorArgs,
      noCompile: true,
    });
    console.log(`✅ Verified ${contractName} at ${contractAddress}`);
  } catch (error) {
    if (error.message.toLowerCase().includes("already verified")) {
      console.log(`ℹ️ ${contractName} already verified.`);
    } else {
      console.error(`❌ Verification failed for ${contractName}:`, error.message);
   //   process.exit(1);
    }
  }
};

const verifyContractProxy = async (contractName, proxyAddress, constructorArgs = []) => {
  try {
    const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log(`📍 Implementation address for ${contractName}:`, implAddress);
    await verifyContract(`${contractName}_Impl`, implAddress, constructorArgs);
  } catch (error) {
    console.error(`❌ Proxy verification failed for ${contractName}:`, error.message);
 //   process.exit(1);
  }
};

const generateConstantFile = (contract, address) => {
  const abi = fetchAbi(contract);
  const camel = contract.charAt(0).toLowerCase() + contract.slice(1);
  const version = process.env.DEPLOYMENT_VERSION ?? '0';

  const data = `
const ${camel}Version = "${version}";
const ${camel}Address = "${address}";
const ${camel}Abi = ${JSON.stringify(abi, null, 2)};
module.exports = { ${camel}Version, ${camel}Address, ${camel}Abi };`;

  if (!fs.existsSync(dirPath)) fs.mkdirSync(dirPath);
  fs.writeFileSync(`${dirPath}/${contract}.js`, data.trim());
  console.log(`✅ ABI + address saved: ${dirPath}/${contract}.js`);
};

async function getFeeData() {
  const { maxFeePerGas, maxPriorityFeePerGas } = await ethers.provider.getFeeData();
  return { maxFeePerGas, maxPriorityFeePerGas };
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("🚀 Deploying from:", deployer.address);

  const feeData = await getFeeData();

  // 1. Deploy KiguToken
  const KiguToken = await ethers.getContractFactory("KiguToken");
  const kiguToken = await KiguToken.deploy();
  await kiguToken.deployed();
  console.log("✅ KiguToken deployed at:", kiguToken.address);

  generateConstantFile("KiguToken", kiguToken.address);
  await verifyContract("KiguToken", kiguToken.address, []);

  // 2. Call initialMint to deployer (or designated address)
  const initialReceiver = deployer.address;

  const mintTx = await kiguToken.initialMint(initialReceiver);
  await mintTx.wait();
  console.log(`✅ initialMint(${initialReceiver} done`);

  // 3. Deploy KiguMinterUpgradeable via Proxy
  const KiguMinter = await ethers.getContractFactory("KiguMinterUpgradeable");
  const kiguMinterProxy = await upgrades.deployProxy(
    KiguMinter,
    [kiguToken.address],
    {
      initializer: "initialize",
      timeout: 180000,
      pollingInterval: 3000,
      ...feeData,
    }
  );
  await kiguMinterProxy.deployed();
  console.log("✅ KiguMinterUpgradeable Proxy deployed at:", kiguMinterProxy.address);

  generateConstantFile("KiguMinterUpgradeable", kiguMinterProxy.address);
  await verifyContractProxy("KiguMinterUpgradeable", kiguMinterProxy.address, []);

  // 4. Set minter on token to the minter proxy
  const setMinterTx = await kiguToken.setMinter(kiguMinterProxy.address);
  await setMinterTx.wait();
  console.log("✅ KiguToken.setMinter(KiguMinter) done");

  // 5. Set minting config


  const configTx = await kiguMinterProxy.setMintingConfig(wallets, percents, decay);
  await configTx.wait();
  console.log("✅ setMintingConfig done");

  // 6. Optionally delegate minter role inside minter
  const newMinter = minterAddress; // replace as needed
  const delegateMinterTx = await kiguMinterProxy.setMinter(newMinter);
  await delegateMinterTx.wait();
  console.log(`✅ KiguMinter.setMinter(${newMinter}) done`);

  // 7. giving ownership to multisig
  const transferOwnershipTx = await kiguMinterProxy.transferOwnership(multiSigAddress);
  await transferOwnershipTx.wait();
  console.log(`✅ KiguMinterUpgradeable ownership transferred to ${multiSigAddress}`);

}

main().then(() => {
  console.log("🎉 Deployment complete.");
}).catch((err) => {
  console.error("❌ Deployment failed:", err);
  process.exit(1);
});
