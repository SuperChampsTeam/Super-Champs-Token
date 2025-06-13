require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@openzeppelin/hardhat-upgrades");


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      // local in-memory Hardhat network
    },
    baseSepolia: {
      url: "https://base-sepolia-rpc.publicnode.com",
      accounts: ["<PRIVATE_TOKEN>"],
      chainId: 84532,
      gas: 20000000,
      gasPrice: 15e9, // 15 Gwei
    },
  },
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      evmVersion: "paris",
    },
  },
  paths: {
    sources: "./SuperChamps", // ✅ Move it here
  },
};