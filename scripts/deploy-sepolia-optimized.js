const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {
  console.log("🚀 Starting optimized Sepolia deployment of ZamaFundVault...\n");
  
  // Use mnemonic to create wallet
  const mnemonic = "caught sea verb winner bunker lake tool vintage topic answer right shiver";
  const wallet = hre.ethers.Wallet.fromMnemonic(mnemonic);
  const deployer = wallet.connect(hre.ethers.provider);
  
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", hre.ethers.formatEther(await deployer.provider.getBalance(deployer.address)));

  // Gas optimization settings
  const gasPrice = hre.ethers.parseUnits("15", "gwei"); // Lower gas price for cost efficiency
  const deployOptions = {
    gasPrice: gasPrice,
    gasLimit: 3000000 // Conservative gas limit
  };

  console.log(`Using gas price: ${hre.ethers.formatUnits(gasPrice, "gwei")} gwei`);

  // Step 1: Deploy ZamaFHEConfig (lightweight)
  console.log("\n⚙️ Deploying ZamaFHEConfig...");
  const ZamaFHEConfig = await hre.ethers.getContractFactory("ZamaFHEConfig", deployer);
  const zamaConfig = await ZamaFHEConfig.deploy(deployOptions);
  await zamaConfig.waitForDeployment();
  console.log("✅ ZamaFHEConfig deployed to:", await zamaConfig.getAddress());

  // Step 2: Deploy ConfidentialMath
  console.log("\n📊 Deploying ConfidentialMath...");
  const ConfidentialMath = await hre.ethers.getContractFactory("ConfidentialMath", deployer);
  const confidentialMath = await ConfidentialMath.deploy(
    await zamaConfig.getAddress(),
    deployOptions
  );
  await confidentialMath.waitForDeployment();
  console.log("✅ ConfidentialMath deployed to:", await confidentialMath.getAddress());

  // Step 3: Deploy CampaignRegistry
  console.log("\n📝 Deploying CampaignRegistry...");
  const CampaignRegistry = await hre.ethers.getContractFactory("CampaignRegistry", deployer);
  const campaignRegistry = await CampaignRegistry.deploy(deployOptions);
  await campaignRegistry.waitForDeployment();
  console.log("✅ CampaignRegistry deployed to:", await campaignRegistry.getAddress());

  // Step 4: Deploy FundVault (main contract)
  console.log("\n💰 Deploying FundVault...");
  const platformFeeRate = 200; // 2% - lower fee for better user experience
  const feeCollector = deployer.address;
  
  const FundVault = await hre.ethers.getContractFactory("FundVault", deployer);
  const fundVault = await FundVault.deploy(
    await campaignRegistry.getAddress(),
    await confidentialMath.getAddress(),
    platformFeeRate,
    feeCollector,
    deployOptions
  );
  await fundVault.waitForDeployment();
  console.log("✅ FundVault deployed to:", await fundVault.getAddress());

  // Step 5: Deploy one test token (minimal deployment)
  console.log("\n🪙 Deploying Test Token...");
  const TestToken = await hre.ethers.getContractFactory("TestToken", deployer);
  const testToken = await TestToken.deploy(
    "ZamaFundToken",
    "ZFT",
    18,
    hre.ethers.parseEther("1000000"), // 1M tokens
    deployOptions
  );
  await testToken.waitForDeployment();
  console.log("✅ ZamaFundToken (ZFT) deployed to:", await testToken.getAddress());

  // Step 6: Minimal setup (gas-efficient)
  console.log("\n⚙️ Setting up permissions...");
  
  // Add FundVault as authorized decryptor
  const tx1 = await confidentialMath.addAuthorizedDecryptor(
    await fundVault.getAddress(),
    { gasPrice: gasPrice, gasLimit: 100000 }
  );
  await tx1.wait();
  console.log("✅ FundVault added as authorized decryptor");

  // Add deployer as verifier in CampaignRegistry
  const tx2 = await campaignRegistry.addVerifier(
    deployer.address,
    { gasPrice: gasPrice, gasLimit: 100000 }
  );
  await tx2.wait();
  console.log("✅ Deployer added as campaign verifier");

  // Calculate total deployment cost
  const finalBalance = await deployer.provider.getBalance(deployer.address);
  const deploymentCost = hre.ethers.formatEther(
    hre.ethers.parseEther(hre.ethers.formatEther(await deployer.provider.getBalance(deployer.address))) - 
    hre.ethers.parseEther(hre.ethers.formatEther(finalBalance))
  );

  // Step 7: Generate deployment summary
  console.log("\n📋 SEPOLIA DEPLOYMENT SUMMARY");
  console.log("=============================");
  console.log(`Network: ${hre.network.name} (Chain ID: ${(await hre.ethers.provider.getNetwork()).chainId})`);
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Gas Price: ${hre.ethers.formatUnits(gasPrice, 'gwei')} gwei`);
  console.log(`Estimated Cost: ~${deploymentCost} ETH`);
  console.log("");
  console.log("📊 Core Contracts:");
  console.log(`├─ ZamaFHEConfig: ${await zamaConfig.getAddress()}`);
  console.log(`├─ ConfidentialMath: ${await confidentialMath.getAddress()}`);
  console.log(`├─ CampaignRegistry: ${await campaignRegistry.getAddress()}`);
  console.log(`├─ FundVault: ${await fundVault.getAddress()}`);
  console.log(`└─ ZamaFundToken (ZFT): ${await testToken.getAddress()}`);

  // Step 8: Save deployment info for frontend
  const deploymentInfo = {
    network: "sepolia",
    chainId: 11155111,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    gasPrice: hre.ethers.formatUnits(gasPrice, 'gwei'),
    contracts: {
      ZamaFHEConfig: await zamaConfig.getAddress(),
      ConfidentialMath: await confidentialMath.getAddress(),
      CampaignRegistry: await campaignRegistry.getAddress(),
      FundVault: await fundVault.getAddress(),
      TestToken: await testToken.getAddress()
    },
    config: {
      platformFeeRate: platformFeeRate,
      feeCollector: feeCollector
    }
  };

  // Save deployment info
  const deploymentsDir = path.join(__dirname, '../deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  
  const filename = `sepolia-deployment-${Date.now()}.json`;
  fs.writeFileSync(
    path.join(deploymentsDir, filename),
    JSON.stringify(deploymentInfo, null, 2)
  );
  
  console.log(`\n💾 Deployment info saved to: deployments/${filename}`);

  // Save contract addresses for frontend
  const contractAddresses = {
    FUND_VAULT_ADDRESS: await fundVault.getAddress(),
    CONFIDENTIAL_MATH_ADDRESS: await confidentialMath.getAddress(),
    CAMPAIGN_REGISTRY_ADDRESS: await campaignRegistry.getAddress(),
    ZAMA_FHE_CONFIG_ADDRESS: await zamaConfig.getAddress(),
    TEST_TOKEN_ADDRESS: await testToken.getAddress(),
    NETWORK: "sepolia",
    CHAIN_ID: 11155111
  };

  // Save to frontend config
  const frontendConfigPath = path.join(__dirname, '../frontend/src/config/contractAddresses.js');
  const configContent = `// Auto-generated contract addresses for Sepolia deployment
// Generated on: ${new Date().toISOString()}

export const CONTRACT_ADDRESSES = ${JSON.stringify(contractAddresses, null, 2)};

export default CONTRACT_ADDRESSES;
`;

  fs.writeFileSync(frontendConfigPath, configContent);
  console.log(`\n🔧 Contract addresses saved to: frontend/src/config/contractAddresses.js`);

  console.log("\n🎉 Sepolia deployment completed successfully!");
  console.log("\n🌐 Next steps:");
  console.log("1. ✅ Contract addresses updated in frontend configuration");
  console.log("2. 🔍 Verify contracts on Sepolia Etherscan");
  console.log("3. 🚀 Start frontend with: npm run frontend");
  console.log("4. 🧪 Test the application at http://localhost:3017");
  
  console.log("\n📱 Contract Interaction URLs:");
  console.log(`├─ FundVault: https://sepolia.etherscan.io/address/${await fundVault.getAddress()}`);
  console.log(`├─ Test Token: https://sepolia.etherscan.io/address/${await testToken.getAddress()}`);
  console.log(`└─ Campaign Registry: https://sepolia.etherscan.io/address/${await campaignRegistry.getAddress()}`);

  return deploymentInfo;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Sepolia deployment failed:", error);
    process.exit(1);
  });