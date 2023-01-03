import "@nomicfoundation/hardhat-toolbox";
import '@openzeppelin/hardhat-upgrades';
import '@openzeppelin/hardhat-upgrades';
import "@dirtycajunrice/hardhat-tasks";
import { HardhatUserConfig } from "hardhat/config";
import { GetEtherscanCustomChains, GetNetworks } from "@dirtycajunrice/hardhat-tasks";

import "dotenv/config";
import "./tasks";

const settings = {
  optimizer: {
    enabled: true,
    runs: 200
  },
  outputSelection: {
    '*': {
      '*': ['storageLayout'],
    },
  },
}

const compilers = ["0.8.17", "0.6.0"].map(version => ({ version, settings }));

const networks = GetNetworks([process.env.PRIVATE_KEY])

const config: HardhatUserConfig = {
  solidity: { compilers },
  networks,
  etherscan: {
    apiKey: {
      harmony: 'not needed',
      harmonyTest: 'not needed',
      optimisticEthereum: process.env.OPTIMISTIC_API_KEY || '',
      polygon: process.env.POLYGONSCAN_API_KEY || '',
      arbitrumOne: process.env.ARBISCAN_API_KEY || '',
      opera: process.env.FTMSCAN_API_KEY || '',
      avalanche: process.env.SNOWTRACE_API_KEY || '',
      cronos: process.env.CRONOSCAN_API_KEY || '',
      boba: 'not needed'
    },
    customChains: GetEtherscanCustomChains()
  }
};

export default config;