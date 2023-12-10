import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      chainId: 1440002,
      forking: {
        url: process.env.XRP_EVM_RPC_URL !== undefined ? process.env.XRP_EVM_RPC_URL : '', // replace with your Infura project ID
        blockNumber: 4700980, // replace with the block number you want to fork from
      },

    },
    xrpevm: {
      url: process.env.XRP_EVM_RPC_URL !== undefined ? process.env.XRP_EVM_RPC_URL : '',
      accounts: process.env.PRIVATE_KEY !== undefined && process.env.PRIVATE_KEY2 !== undefined ?
          [process.env.PRIVATE_KEY, process.env.PRIVATE_KEY2] : [],
      chainId: 1440002,
      gas: 12000000
    },

  },
};

export default config;
