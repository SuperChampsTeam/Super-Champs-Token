require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-web3");
require("dotenv").config();

module.exports = {
  // Latest Solidity version
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          metadata: {
            useLiteralContent: true
          }
        },
      },
    ],
  },

  networks: {
    avalanche: {
      url: `${process.env.RPC_URL}`, // AVALANCHE Mainnet RPC
      chainId: 43114,
      accounts: [`0x${process.env.PRIVATEKEY}`],
    },
    sepolia: {
      url: `${process.env.RPC_URL}`, // Sepolia Testnet RPC
      chainId: 11155111,
      accounts: [`0x${process.env.PRIVATEKEY}`],
    },
    baseSepolia: {
      url: `${process.env.RPC_URL}`, // Base Sepolia Testnet RPC
      chainId: 84532,
      accounts: [`0x${process.env.PRIVATEKEY}`],
    },
    base: {
      url: `${process.env.RPC_URL}`, // Base Sepolia Testnet RPC
      chainId: 8453,
      accounts: [`0x${process.env.PRIVATEKEY}`],
    },
    fuji: {
      url: `${process.env.RPC_URL}`, // Fuji Testnet RPC
      chainId: 43113,
      accounts: [`0x${process.env.PRIVATEKEY}`],
    },
  },

  etherscan: {
    apiKey: `${process.env.APIKEY}`,
    customChains: [
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=84532",
          browserURL: "https://sepolia.basescan.org",
        },
      },
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=8453",
          browserURL: "https://basescan.org",
        },
      },
    ],
  },

  mocha: {
    timeout: 100000000,
  },
  paths: {
    sources: "./SuperChamps",
  }
};
