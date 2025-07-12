const { ethers, upgrades, run } = require("hardhat");
const { fetchAbi } = require('./abi-fetcher.js');
const fs = require('fs');

const dirPath = './generated';

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

const scLockProxyAddress = '0xB7c735DcCD4e995b18c650Bc73c2F8AB2D7fCC8d';

async function main() {

  const scLockContract = await ethers.getContractFactory("SCLock");
  const scLock = await ethers.getContractAt("SCLock", scLockProxyAddress);
  const owner = await scLock.owner();

  const adminAddress = await upgrades.erc1967.getAdminAddress(scLockProxyAddress);
  console.log("Proxy admin address is:", adminAddress);

  console.log("scLock owner is:", owner);
  const [signer] = await ethers.getSigners();
  console.log("Deployer signer is:", await signer.getAddress());
  console.log("owner: ", await scLock.owner());

  await upgrades.forceImport(scLockProxyAddress, scLockContract);

  try {
    const upgradedSclock = await upgrades.upgradeProxy(scLockProxyAddress, scLockContract, {
      redeployImplementation: "always",
      timeout: 180000, // if your network is slow, you can bump this
      pollingInterval: 3000, // likewise, poll every 3s
    });
    await upgradedSclock.deployed();
    console.log("scLock address: ", upgradedSclock.address);
    generateConstantFile("SClock", upgradedSclock.address);
  } catch (error) {
    console.log("error ", error);
  }
}

main().then(() => console.log("Done!"));
