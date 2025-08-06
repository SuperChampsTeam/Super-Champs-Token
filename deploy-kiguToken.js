const { ethers, upgrades, run } = require("hardhat");
const { fetchAbi } = require('./abi-fetcher.js');
const fs = require("fs");

const dirPath = './generated';

const initalMintAddress = process.env.INITIAL_MINT_ADDRESS;
const firstAddress = process.env.FIRST_ADDRESS;
const secondAddress = process.env.SECOND_ADDRESS;
const thirdAddress = process.env.THIRD_ADDRESS;
const fourthAddress = process.env.FOURTH_ADDRESS;
const minterManager = process.env.MINTER_MANAGER_ADDRESS; // your EOA wallet to manage emissions

console.log("VARS", initalMintAddress, firstAddress, secondAddress, thirdAddress, fourthAddress, minterManager);
if (!initalMintAddress || !firstAddress || !secondAddress || !thirdAddress || !fourthAddress || !minterManager) {
  console.error("environment variables not set");
  process.exit(1);
}

const wallets = [firstAddress, secondAddress, thirdAddress, fourthAddress];
const percents = [0, 3667, 2666, 3667];


const getFeeData = async () => {
  const fee = await ethers.provider.getFeeData();
  return {
    maxFeePerGas: fee.maxFeePerGas,
    maxPriorityFeePerGas: fee.maxPriorityFeePerGas,
  };
};



const verifyContract = async (name, address, args = []) => {
  try {
    await run("verify:verify", {
      address,
      constructorArguments: args,
      noCompile: true,
    });
    console.log(`✅ Verified ${name} at ${address}`);
  } catch (err) {
    if (err.message.toLowerCase().includes("already verified")) {
      console.log(`ℹ️ ${name} already verified.`);
    } else {
      console.error(`❌ Verification failed for ${name}:`, err.message);
    }
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

async function deployKiguToken() {
  const KiguToken = await ethers.getContractFactory("KiguToken");
  const feeData = await getFeeData();
  const kiguToken = await KiguToken.deploy({...feeData});
  await kiguToken.deployed();
  console.log("✅ KiguToken deployed:", kiguToken.address);
  generateConstantFile("KiguToken", kiguToken.address);
  await verifyContract("KiguToken", kiguToken.address);
  return kiguToken.address;
}


async function initialMint(kiguTokenAddress) {
  const kiguTokenAbi = fetchAbi("KiguToken");
  const kiguTokenContract = await ethers.getContractAt(kiguTokenAbi, kiguTokenAddress);
  const feeData = await getFeeData();
  const mintTx = await kiguTokenContract.initialMint(initalMintAddress, {...feeData});
  await mintTx.wait();
  console.log("✅ initialMint to:", initalMintAddress);
}


async function deployKiguEmission(kiguTokenAddress) {
  const KiguEmission = await ethers.getContractFactory("KiguEmission");
  const feeData = await getFeeData();
  const emission = await KiguEmission.deploy(kiguTokenAddress, { ...feeData });
  await emission.deployed();
  console.log("✅ KiguEmission deployed:", emission.address);
  generateConstantFile("KiguEmission", emission.address);
  await verifyContract("KiguEmission", emission.address, [kiguTokenAddress]);
  return emission.address;
}

async function setWalletsAndPercentsAndEmissionManager(kiguEmissionAddress) {
  const kiguEmissionAbi = fetchAbi("KiguEmission");
  const kiguEmissionContract = await ethers.getContractAt(kiguEmissionAbi, kiguEmissionAddress);
  const feeData = await getFeeData();
  const setWalletsAndPercentsTx = await kiguEmissionContract.setWalletsAndPercents(wallets, percents, {...feeData});
  await setWalletsAndPercentsTx.wait();
  const feeData1 = await getFeeData();
  const setEmissionManagerTx = await kiguEmissionContract.setEmissionManager(minterManager, {...feeData1});
  await setEmissionManagerTx.wait();
  console.log("✅ Emission config done");
}

async function deployKiguMinter(kiguTokenAddress, kiguEmissionAddress) {
  const KiguMinter = await ethers.getContractFactory("KiguMinter"); // naming kept for consistency
  const feeData = await getFeeData();
  const kiguMinter = await KiguMinter.deploy(kiguTokenAddress, kiguEmissionAddress, {...feeData});
  await kiguMinter.deployed();
  console.log("✅ KiguMinter deployed:", kiguMinter.address);
  generateConstantFile("KiguMinter", kiguMinter.address); // still usable
  await verifyContract("KiguMinter", kiguMinter.address, [kiguTokenAddress, kiguEmissionAddress]);
  return kiguMinter.address;
}

async function setMinterInKiguToken(kiguTokenAddress, kiguMinterAddress) {
  const kiguTokenAbi = fetchAbi("KiguToken");
  const kiguTokenContract = await ethers.getContractAt(kiguTokenAbi, kiguTokenAddress);
  const feeData = await getFeeData();
  const setMinterInKiguTokenTx = await kiguTokenContract.setMinter(kiguMinterAddress, {...feeData});
  await setMinterInKiguTokenTx.wait();
  console.log("✅ Token.setMinter done");
}

async function setMinterInKiguEmission(kiguEmissionAddress, kiguMinterAddress) {
  const kiguEmissionAbi = fetchAbi("KiguEmission");
  const kiguEmissionContract = await ethers.getContractAt(kiguEmissionAbi, kiguEmissionAddress);
  const feeData = await getFeeData();
  const setMinterInEmissionTx = await kiguEmissionContract.setMinter(kiguMinterAddress, { ...feeData });
  await setMinterInEmissionTx.wait();
  console.log("✅ Emission.setMinter done");
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("🚀 Deployer:", deployer.address);


// 1. Deploy KiguToken
  const kiguTokenAddress = await deployKiguToken();

// 2. Initial mint
  await initialMint(kiguTokenAddress);

  // 3. Deploy KiguEmission (upgradeable)
  const kiguEmissionAddress = await deployKiguEmission(kiguTokenAddress);

  // 4. Set emission wallets & config
  await setWalletsAndPercentsAndEmissionManager(kiguEmissionAddress);

  // 5. Deploy KiguMinter (regular contract)
  const kiguMinterAddress = await deployKiguMinter(kiguTokenAddress, kiguEmissionAddress);

  // 6. Set minter in KiguToken
  await setMinterInKiguToken(kiguTokenAddress, kiguMinterAddress);

  // 7. Set minter in Emission
  await setMinterInKiguEmission(kiguEmissionAddress, kiguMinterAddress);
}

main().then(() => {
  console.log("🎉 Full deployment complete.");
}).catch((err) => {
  console.error("❌ Deployment failed:", err);
  process.exit(1);
});
