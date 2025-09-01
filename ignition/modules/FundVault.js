const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("FundVaultModule", (m) => {
  // Deploy parameters
  const platformFeeRate = m.getParameter("platformFeeRate", 250); // 2.5%
  const feeCollector = m.getParameter("feeCollector", "0x742d35Cc6634C0532925a3b8D0CDAD5d4F4b8f32");
  
  // Deploy ZamaFHEConfig first
  const zamaConfig = m.contract("ZamaFHEConfig");
  
  // Deploy ConfidentialMath with Zama config
  const confidentialMath = m.contract("ConfidentialMath", [zamaConfig]);
  
  // Deploy CampaignRegistry
  const campaignRegistry = m.contract("CampaignRegistry");
  
  // Deploy FundVault with dependencies
  const fundVault = m.contract("FundVault", [
    campaignRegistry,
    confidentialMath,
    platformFeeRate,
    feeCollector
  ]);
  
  // Deploy SecretSwap
  const secretSwap = m.contract("SecretSwap", [confidentialMath]);
  
  // Deploy test tokens
  const testTokenA = m.contract("TestToken", [
    "ZamaTestToken",
    "ZTT",
    18,
    ethers.parseEther("1000000") // 1M tokens
  ]);
  
  const testTokenB = m.contract("TestToken", [
    "ConfidentialCoin", 
    "CONF",
    18,
    ethers.parseEther("500000") // 500K tokens
  ]);

  return { 
    zamaConfig,
    fundVault, 
    campaignRegistry, 
    confidentialMath, 
    secretSwap,
    testTokenA,
    testTokenB
  };
});