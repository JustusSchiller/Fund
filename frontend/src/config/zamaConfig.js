// Zama FHE Configuration for ZamaFundVault
export const ZAMA_CONFIG = {
  // Sepolia Testnet Addresses
  SEPOLIA: {
    chainId: 11155111,
    name: 'Sepolia Testnet',
    rpcUrl: 'https://sepolia.infura.io/v3/',
    
    // Zama FHE Contract Addresses
    contracts: {
      FHEVM_EXECUTOR: '0x848B0066793BcC60346Da1F49049357399B8D595',
      ACL_CONTRACT: '0x687820221192C5B662b25367F70076A37bc79b6c',
      HCU_LIMIT_CONTRACT: '0x594BB474275918AF9609814E68C61B1587c5F838',
      KMS_VERIFIER: '0x1364cBBf2cDF5032C47d8226a6f6FBD2AFCDacAC',
      INPUT_VERIFIER: '0xbc91f3daD1A5F19F8390c400196e58073B6a0BC4',
      DECRYPTION_ORACLE: '0xa02Cda4Ca3a71D7C46997716F4283aa851C28812',
      DECRYPTION_ADDRESS: '0xb6E160B1ff80D67Bfe90A85eE06Ce0A2613607D1',
      INPUT_VERIFICATION_ADDRESS: '0x7048C39f048125eDa9d678AEbaDfB22F7900a29F'
    },
    
    // Zama Services
    relayerUrl: 'https://relayer.testnet.zama.cloud',
    
    // Block Explorer
    explorer: 'https://sepolia.etherscan.io'
  },

  // Local Development (Hardhat)
  LOCAL: {
    chainId: 1337,
    name: 'Local Development',
    rpcUrl: 'http://127.0.0.1:8545',
    
    // Will be populated after deployment
    contracts: {
      FHEVM_EXECUTOR: null,
      ACL_CONTRACT: null,
      HCU_LIMIT_CONTRACT: null,
      KMS_VERIFIER: null,
      INPUT_VERIFIER: null,
      DECRYPTION_ORACLE: null,
      DECRYPTION_ADDRESS: null,
      INPUT_VERIFICATION_ADDRESS: null
    },
    
    relayerUrl: 'http://localhost:8080', // Local relayer for development
    explorer: null
  }
};

/**
 * Get Zama configuration for current network
 * @param {number} chainId - Chain ID
 * @returns {object} Zama configuration
 */
export function getZamaConfig(chainId) {
  switch (chainId) {
    case 11155111:
      return ZAMA_CONFIG.SEPOLIA;
    case 1337:
      return ZAMA_CONFIG.LOCAL;
    default:
      console.warn(`Unsupported network: ${chainId}`);
      return ZAMA_CONFIG.SEPOLIA; // Default to Sepolia
  }
}

/**
 * Check if FHE is supported on current network
 * @param {number} chainId - Chain ID
 * @returns {boolean} True if FHE is supported
 */
export function isFHESupported(chainId) {
  return chainId === 11155111 || chainId === 1337;
}

/**
 * Get contract address by name
 * @param {number} chainId - Chain ID
 * @param {string} contractName - Contract name
 * @returns {string|null} Contract address
 */
export function getContractAddress(chainId, contractName) {
  const config = getZamaConfig(chainId);
  return config.contracts[contractName] || null;
}

/**
 * Validate FHE setup for current network
 * @param {number} chainId - Chain ID
 * @returns {boolean} True if valid setup
 */
export function validateFHESetup(chainId) {
  const config = getZamaConfig(chainId);
  
  // For local development, we might not have all contracts deployed
  if (chainId === 1337) {
    return true; // Allow local development
  }
  
  // For testnet/mainnet, validate all contracts are present
  const requiredContracts = [
    'FHEVM_EXECUTOR',
    'ACL_CONTRACT', 
    'KMS_VERIFIER',
    'INPUT_VERIFIER',
    'DECRYPTION_ORACLE'
  ];
  
  return requiredContracts.every(contract => 
    config.contracts[contract] && config.contracts[contract] !== null
  );
}

export default ZAMA_CONFIG;