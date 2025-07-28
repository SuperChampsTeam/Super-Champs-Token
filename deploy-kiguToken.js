const { ethers, upgrades, run } = require("hardhat");
const { fetchAbi } = require('./abi-fetcher.js');
const fs = require("fs");

const dirPath = './generated';

const initalMintAddress = "0x97ecd0c78bccec8c4be2a5c0d4e2ece81dcef5ea";
const firstAddress = "0x97ecd0c78bccec8c4be2a5c0d4e2ece81dcef5ea";
const secondAddress = "0x8623b03c93f88f537BD65908D7283e8c0E116d1D";
const thirdAddress = "0x2d7869299C9cB7Ba3a702F172FC3a0079D82A1Db";
const fourthAddress = "0x8623b03c93f88f537BD65908D7283e8c0E116d1D";
const minterEOA = "0x2d7869299C9cB7Ba3a702F172FC3a0079D82A1Db"; // your EOA wallet to manage emissions
const multiSigAddress = "0x52082AF7f3AA5DCB8f12625136f50B88067528Ea";

const wallets = [firstAddress, secondAddress, thirdAddress, fourthAddress];
const percents = [6667, 1333, 1333, 667];
const decay = 300;

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

const verifyContractProxy = async (name, proxyAddress) => {
  try {
    const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log(`📍 Impl address for ${name}: ${implAddress}`);
    await verifyContract(`${name}_Impl`, implAddress);
  } catch (err) {
    console.error(`❌ Proxy verification failed for ${name}:`, err.message);
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

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("🚀 Deployer:", deployer.address);
  const feeData = await ethers.provider.getFeeData();

  // 1. Deploy KiguToken
  const KiguToken = await ethers.getContractFactory("KiguToken");
  const kiguToken = await KiguToken.deploy();
  await kiguToken.deployed();
  console.log("✅ KiguToken deployed:", kiguToken.address);
  generateConstantFile("KiguToken", kiguToken.address);
  await verifyContract("KiguToken", kiguToken.address);

  // 2. Initial mint
  const mintTx = await kiguToken.initialMint(initalMintAddress);
  await mintTx.wait();
  console.log("✅ initialMint to:",initalMintAddress);

  // 3. Deploy KiguEmission (upgradeable)
  const KiguEmission = await ethers.getContractFactory("KiguEmission");
  const emission = await upgrades.deployProxy(
    KiguEmission,
    [kiguToken.address],
    {
      initializer: "initialize",
      timeout: 180000,
      pollingInterval: 3000,
      ...feeData,
    }
  );
  await emission.deployed();
  console.log("✅ KiguEmission deployed (proxy):", emission.address);
  generateConstantFile("KiguEmission", emission.address);
  await verifyContractProxy("KiguEmission", emission.address);

  // 4. Set emission wallets & config
  await (await emission.setWalletsAndPercents(wallets, percents)).wait();
  await (await emission.setEmissionManager(minterEOA)).wait();
  console.log("✅ Emission config done");

  // 5. Deploy KiguMinter (regular contract)
  const KiguMinter = await ethers.getContractFactory("KiguMinter"); // naming kept for consistency
  const kiguMinter = await KiguMinter.deploy(kiguToken.address, emission.address);
  await kiguMinter.deployed();
  console.log("✅ KiguMinter deployed:", kiguMinter.address);
  generateConstantFile("KiguMinter", kiguMinter.address); // still usable
  await verifyContract("KiguMinter", kiguMinter.address, [
    kiguToken.address,
    emission.address,
  ]);

  // 6. Set minter in KiguToken
  await (await kiguToken.setMinter(kiguMinter.address)).wait();
  console.log("✅ Token.setMinter done");

  // 7. Set minter in Emission
  await (await emission.setMinter(kiguMinter.address)).wait();
  console.log("✅ Emission.setMinter done");

  // Optional: Transfer ownership to multisig
  await (await emission.transferOwnership(multiSigAddress)).wait();
  console.log(`✅ KiguEmission ownership transferred to ${multiSigAddress}`);
}

main().then(() => {
  console.log("🎉 Full deployment complete.");
}).catch((err) => {
  console.error("❌ Deployment failed:", err);
  process.exit(1);
});
