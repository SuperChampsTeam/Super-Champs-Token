const { ethers, upgrades, run } = require("hardhat");
const { fetchAbi } = require('./abi-fetcher.js');
const fs = require('fs');

const dirPath = './generated';

// const verifyContractProxy = async (contractName, contractAddress, constructorArgs = []) => {
//   try {
//     const implAddress = await upgrades.erc1967.getImplementationAddress(contractAddress);
//     console.log("Implementation address:", implAddress);

//     await verifyContract(contractName, implAddress, constructorArgs);
//   } catch (error) {
//     if (error.message.toLowerCase().includes("already verified")) {
//       console.log(`ℹ️ Contract ${contractName} is already verified.`);
//     } else {
//       console.error(`❌ Verification failed for ${contractName}:`, error.message);
//       process.exit(1);
//     }
//   }
// };

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

async function getFeeData() {
  const { maxFeePerGas, maxPriorityFeePerGas } = await ethers.provider.getFeeData();
  return { maxFeePerGas, maxPriorityFeePerGas };
}

// const deploySCLock = async () => {
//   try {
//     const SCLockFactory = await ethers.getContractFactory("SCLock");
//     // const feeData = await getFeeData();

//     // const scLockProxy = await upgrades.deployProxy(
//     //   SCLockFactory,
//     //   ['0xEb6d78148F001F3aA2f588997c5E102E489Ad341'], // constructor args
//     //   {
//     //     initializer: "initialize",
//     //     timeout: 180000,
//     //     pollingInterval: 3000,
//     //     ...feeData,
//     //   }
//     // );

//     await SCLockFactory.deployed();
//     console.log("✅ SCLock Address: ", SCLockFactory.address);

//     generateConstantFile("SCLock", SCLockFactory.address);
//     await verifyContract("SCLock", SCLockFactory.address, []);
//   } catch (error) {
//     console.error("❌ Error in deploySCLock: ", error);
//     process.exit(1);
//   }
// };

const deploySCLock = async () => {
  try {
    const tokenAddress = "0xEb6d78148F001F3aA2f588997c5E102E489Ad341"; // ← your ERC-20
    const SCLockFactory = await ethers.getContractFactory("SCLock");
    const feeData = await getFeeData();

    // direct deployment (no proxy)
    const scLock = await SCLockFactory.deploy(tokenAddress, { ...feeData });
    await scLock.deployed();
    console.log("✅ SCLock deployed at:", scLock.address);

    generateConstantFile("SCLock", scLock.address);
    await verifyContract("SCLock", scLock.address, [tokenAddress]);
  } catch (err) {
    console.error("❌ Error deploying SCLock:", err);
    process.exit(1);
  }
};

async function main() {
  await deploySCLock();
}

main()
  .then(() => console.log("🎉 Done!"))
  .catch((err) => {
    console.error("❌ Error in main execution: ", err);
    process.exit(1);
  });
