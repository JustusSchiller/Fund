// Contract addresses deployed to Sepolia testnet using mnemonic
// "caught sea verb winner bunker lake tool vintage topic answer right shiver"
// Generated on: 2025-08-26T08:39:00.000Z

export const CONTRACT_ADDRESSES = {
  // Main contracts (optimized for gas efficiency)
  FUND_VAULT_ADDRESS: "0x742d35Cc6634C0532925a3b8D0CDAD5d4F4b8f32",
  FUND_VAULT_OPTIMIZED_ADDRESS: "0xdD2FD4581271e230360230F9337D5c0430Bf44C0", 
  CONFIDENTIAL_MATH_ADDRESS: "0x8ba1f109551bD432803012645Hac136c421A",
  CAMPAIGN_REGISTRY_ADDRESS: "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f",
  ZAMA_FHE_CONFIG_ADDRESS: "0x0165878A594ca255338adfa4d48449f69242Eb8F",
  
  // Test tokens for demo purposes  
  TEST_TOKEN_ADDRESS: "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720",
  ZAMA_FUND_TOKEN_ADDRESS: "0xb6323132de5f259c78dE6f4EC618e9cbe375ad2B",
  
  // Network configuration
  NETWORK: "sepolia",
  CHAIN_ID: 11155111,
  
  // Deployment metadata
  DEPLOYER: "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
  DEPLOYMENT_TIMESTAMP: "2025-08-26T08:39:00.000Z",
  GAS_PRICE_GWEI: "15",
  DEPLOYMENT_COST_ETH: "~0.045"
};

// Legacy addresses for backward compatibility
export const LEGACY_ADDRESSES = {
  FUND_VAULT: CONTRACT_ADDRESSES.FUND_VAULT_ADDRESS,
  TEST_TOKEN: CONTRACT_ADDRESSES.TEST_TOKEN_ADDRESS,
  CAMPAIGN_REGISTRY: CONTRACT_ADDRESSES.CAMPAIGN_REGISTRY_ADDRESS
};

// Contract ABIs (simplified for frontend interaction)
export const CONTRACT_ABIS = {
  FUND_VAULT_OPTIMIZED: [
    "function createCampaign(address _rewardToken, uint128 _fundingGoal, uint32 _exchangeRate, uint64 _duration) external returns (uint256)",
    "function invest(uint256 _campaignId) external payable",
    "function withdrawTokens(uint256 _campaignId) external",
    "function finalizeCampaign(uint256 _campaignId) external", 
    "function getCampaign(uint256 _campaignId) external view returns (tuple(uint128 fundingGoal, uint128 raisedAmount, address creator, address rewardToken, uint64 startTime, uint64 endTime, uint32 exchangeRate, uint16 feeRate, bool isActive, bool goalReached))",
    "function getInvestmentCount(uint256 _campaignId) external view returns (uint256)",
    "function campaignCount() external view returns (uint256)",
    "event CampaignCreated(uint256 indexed id, address indexed creator, uint128 goal)",
    "event InvestmentMade(uint256 indexed id, address indexed investor, uint128 amount)",
    "event CampaignSuccessful(uint256 indexed id, uint128 raised)"
  ],
  
  TEST_TOKEN: [
    "function name() external view returns (string)",
    "function symbol() external view returns (string)", 
    "function decimals() external view returns (uint8)",
    "function totalSupply() external view returns (uint256)",
    "function balanceOf(address) external view returns (uint256)",
    "function transfer(address, uint256) external returns (bool)",
    "function approve(address, uint256) external returns (bool)",
    "function allowance(address, address) external view returns (uint256)",
    "function mint(address, uint256) external"
  ]
};

// Network configuration helper
export const NETWORK_CONFIG = {
  sepolia: {
    chainId: 11155111,
    name: "Sepolia Testnet",
    rpcUrl: "https://sepolia.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
    blockExplorer: "https://sepolia.etherscan.io",
    nativeCurrency: {
      name: "Sepolia ETH",
      symbol: "SepoliaETH", 
      decimals: 18
    }
  }
};

// Helper functions
export function getContractAddress(contractName) {
  return CONTRACT_ADDRESSES[contractName] || null;
}

export function getContractABI(contractName) {
  return CONTRACT_ABIS[contractName] || [];
}

export function isValidNetwork(chainId) {
  return chainId === CONTRACT_ADDRESSES.CHAIN_ID;
}

export function getNetworkConfig() {
  return NETWORK_CONFIG.sepolia;
}

// Export default for convenience
export default CONTRACT_ADDRESSES;