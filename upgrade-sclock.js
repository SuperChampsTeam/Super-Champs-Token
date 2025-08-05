const { ethers, upgrades, run } = require("hardhat");
const { fetchAbi } = require('./abi-fetcher.js');
const fs = require('fs');

const dirPath = './generated';

const verifyContractProxy = async (contractName, contractAddress, constructorArgs = []) => {
  try {
    const implAddress = await upgrades.erc1967.getImplementationAddress(contractAddress);
    console.log("Implementation address:", implAddress);

    await verifyContract(contractName, implAddress, constructorArgs);
  } catch (error) {
    if (error.message.toLowerCase().includes("already verified")) {
      console.log(`ℹ️ Contract ${contractName} is already verified.`);
    } else {
      console.error(`❌ Verification failed for ${contractName}:`, error.message);
      process.exit(1);
    }
  }
};

const verifyContract = async (contractName, contractAddress, constructorArgs = []) => {
  try {
    const noCompile = true;
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: constructorArgs,
      noCompile,
    });
    console.log(`✅ Verification successful for ${contractName}!`);
  } catch (error) {
    if (error.message.toLowerCase().includes("already verified")) {
      console.log(`ℹ️ Contract ${contractName} is already verified.`);
    } else {
      console.error(`❌ Verification failed for ${contractName}:`, error.message);
      process.exit(1);
    }
  }
};

const generateConstantFile = (contract, address) => {
  try {
    const abi = fetchAbi(contract);

    const contractCamelCase = contract.charAt(0).toLowerCase() + contract.slice(1);
    const contractCamelCaseVersion = process.env.DEPLOYMENT_VERSION ?? '0';
    const contractData =
      `const ${contractCamelCase}Version = "${contractCamelCaseVersion}";\n\n` +
      `const ${contractCamelCase}Address = "${address}";\n\n` +
      `const ${contractCamelCase}Abi = ${JSON.stringify(abi, null, 2)};\n\n` +
      `module.exports = { ${contractCamelCase}Address, ${contractCamelCase}Abi, ${contractCamelCase}Version };`;

    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath, { recursive: true });
    }

    const filename = contract.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase();
    const pathname = `${dirPath}/${filename}.js`;
    fs.writeFileSync(pathname, contractData);
    console.log(`✅ Data written to ${pathname}\n`);
  } catch (error) {
    console.error("❌ Error generating constant file: ", error);
  }
};

const getFeeData = async () => {
  const { maxFeePerGas, maxPriorityFeePerGas } = await ethers.provider.getFeeData();
  return { maxFeePerGas, maxPriorityFeePerGas };
};

const upgradeSCLock = async () => {
  try {
    const proxyAddress = "0x93766606E18104FC328766F10dbA78174A2eCf53"; // Replace with your actual proxy address
    const SCLockFactory = await ethers.getContractFactory("SCLock");
    const feeData = await getFeeData();

    console.log("📦 Old implementation address:", await upgrades.erc1967.getImplementationAddress(proxyAddress));
    console.log("🔁 Upgrading proxy...");

     // Register existing proxy with the upgrade plugin
    const proxy = await upgrades.forceImport(proxyAddress, SCLockFactory);

    console.log("✅ Proxy force-imported at:", proxy.address);

    const upgraded = await upgrades.upgradeProxy(proxyAddress, SCLockFactory, {
      redeployImplementation: "always",
      kind: "transparent",
      ...feeData,
    });
    await upgraded.deployed();

    console.log("🔁 Upgrade complete. Proxy address:", upgraded.address);
    console.log("🎯 New implementation address:", await upgrades.erc1967.getImplementationAddress(proxyAddress));

    console.log("✅ Upgrade complete. Proxy address:", upgraded.address);
    const newImpl = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log("🎯 New implementation address:", newImpl);

    generateConstantFile("SCLock", proxyAddress);
    await verifyContractProxy("SCLock", proxyAddress, []);
  } catch (error) {
    console.error("❌ Error in upgradeSCLock: ", error);
    process.exit(1);
  }
};

async function main() {
  await upgradeSCLock();
}

main()
  .then(() => console.log("🎉 SCLock upgrade done!"))
  .catch((err) => {
    console.error("❌ Error in main execution: ", err);
    process.exit(1);
  });
