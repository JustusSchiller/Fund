const hre = require("hardhat");

async function main() {
  console.log("🚀 Starting comprehensive deployment of ZamaFundVault...\n");
  
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", hre.ethers.formatEther(await deployer.provider.getBalance(deployer.address)));

  // Step 1: Deploy ZamaFHEConfig
  console.log("\n⚙️ Deploying ZamaFHEConfig...");
  const ZamaFHEConfig = await hre.ethers.getContractFactory("ZamaFHEConfig");
  const zamaConfig = await ZamaFHEConfig.deploy();
  await zamaConfig.waitForDeployment();
  console.log("✅ ZamaFHEConfig deployed to:", await zamaConfig.getAddress());

  // Step 2: Deploy ConfidentialMath
  console.log("\n📊 Deploying ConfidentialMath...");
  const ConfidentialMath = await hre.ethers.getContractFactory("ConfidentialMath");
  const confidentialMath = await ConfidentialMath.deploy(await zamaConfig.getAddress());
  await confidentialMath.waitForDeployment();
  console.log("✅ ConfidentialMath deployed to:", await confidentialMath.getAddress());

  // Step 3: Deploy CampaignRegistry
  console.log("\n📝 Deploying CampaignRegistry...");
  const CampaignRegistry = await hre.ethers.getContractFactory("CampaignRegistry");
  const campaignRegistry = await CampaignRegistry.deploy();
  await campaignRegistry.waitForDeployment();
  console.log("✅ CampaignRegistry deployed to:", await campaignRegistry.getAddress());

  // Step 4: Deploy FundVault
  console.log("\n💰 Deploying FundVault...");
  const platformFeeRate = 250; // 2.5%
  const feeCollector = deployer.address; // Use deployer as fee collector for testing
  
  const FundVault = await hre.ethers.getContractFactory("FundVault");
  const fundVault = await FundVault.deploy(
    await campaignRegistry.getAddress(),
    await confidentialMath.getAddress(),
    platformFeeRate,
    feeCollector
  );
  await fundVault.waitForDeployment();
  console.log("✅ FundVault deployed to:", await fundVault.getAddress());

  // Step 5: Deploy SecretSwap
  console.log("\n🔄 Deploying SecretSwap...");
  const SecretSwap = await hre.ethers.getContractFactory("SecretSwap");
  const secretSwap = await SecretSwap.deploy(await confidentialMath.getAddress());
  await secretSwap.waitForDeployment();
  console.log("✅ SecretSwap deployed to:", await secretSwap.getAddress());

  // Step 6: Deploy Test Tokens
  console.log("\n🪙 Deploying Test Tokens...");
  
  const TestToken = await hre.ethers.getContractFactory("TestToken");
  
  // Deploy ZamaTestToken (ZTT)
  const testTokenA = await TestToken.deploy(
    "ZamaTestToken",
    "ZTT", 
    18,
    hre.ethers.parseEther("1000000") // 1M tokens
  );
  await testTokenA.waitForDeployment();
  console.log("✅ ZamaTestToken (ZTT) deployed to:", await testTokenA.getAddress());

  // Deploy ConfidentialCoin (CONF)
  const testTokenB = await TestToken.deploy(
    "ConfidentialCoin",
    "CONF",
    18, 
    hre.ethers.parseEther("500000") // 500K tokens
  );
  await testTokenB.waitForDeployment();
  console.log("✅ ConfidentialCoin (CONF) deployed to:", await testTokenB.getAddress());

  // Step 7: Setup permissions and configurations
  console.log("\n⚙️ Setting up permissions and configurations...");
  
  // Add FundVault as authorized decryptor
  await confidentialMath.addAuthorizedDecryptor(await fundVault.getAddress());
  console.log("✅ FundVault added as authorized decryptor");

  // Add SecretSwap as authorized decryptor
  await confidentialMath.addAuthorizedDecryptor(await secretSwap.getAddress());
  console.log("✅ SecretSwap added as authorized decryptor");

  // Add deployer as verifier in CampaignRegistry
  await campaignRegistry.addVerifier(deployer.address);
  console.log("✅ Deployer added as campaign verifier");

  // Step 8: Create a test trading pair in SecretSwap
  console.log("\n🔄 Creating test trading pair...");
  const pairId = await secretSwap.createTradingPair.staticCall(
    await testTokenA.getAddress(),
    await testTokenB.getAddress(),
    30 // 0.3% fee
  );
  await secretSwap.createTradingPair(
    await testTokenA.getAddress(),
    await testTokenB.getAddress(),
    30
  );
  console.log("✅ Trading pair created with ID:", pairId);

  // Step 9: Airdrop test tokens
  console.log("\n🎁 Airdropping test tokens...");
  const testAccounts = [
    deployer.address,
    "0x742d35Cc6634C0532925a3b8D0CDAD5d4F4b8f32",
    "0xdD2FD4581271e230360230F9337D5c0430Bf44C0"
  ];
  
  const airdropAmount = hre.ethers.parseEther("10000");
  
  for (const account of testAccounts) {
    try {
      await testTokenA.airdrop([account], airdropAmount);
      await testTokenB.airdrop([account], airdropAmount);
      console.log(`✅ Airdropped tokens to ${account}`);
    } catch (error) {
      console.log(`⚠️ Could not airdrop to ${account}:`, error.message);
    }
  }

  // Step 10: Generate deployment summary
  console.log("\n📋 DEPLOYMENT SUMMARY");
  console.log("=====================");
  console.log(`Network: ${hre.network.name}`);
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Gas Price: ${hre.ethers.formatUnits(await hre.ethers.provider.getFeeData().then(f => f.gasPrice || 0), 'gwei')} gwei`);
  console.log("");
  console.log("📊 Core Contracts:");
  console.log(`├─ ZamaFHEConfig: ${await zamaConfig.getAddress()}`);
  console.log(`├─ ConfidentialMath: ${await confidentialMath.getAddress()}`);
  console.log(`├─ CampaignRegistry: ${await campaignRegistry.getAddress()}`);
  console.log(`├─ FundVault: ${await fundVault.getAddress()}`);
  console.log(`└─ SecretSwap: ${await secretSwap.getAddress()}`);
  console.log("");
  console.log("🪙 Test Tokens:");
  console.log(`├─ ZamaTestToken (ZTT): ${await testTokenA.getAddress()}`);
  console.log(`└─ ConfidentialCoin (CONF): ${await testTokenB.getAddress()}`);
  console.log("");
  console.log("🔄 Trading Pairs:");
  console.log(`└─ ZTT/CONF: ${pairId}`);

  // Step 11: Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    chainId: (await hre.ethers.provider.getNetwork()).chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      ZamaFHEConfig: await zamaConfig.getAddress(),
      ConfidentialMath: await confidentialMath.getAddress(),
      CampaignRegistry: await campaignRegistry.getAddress(), 
      FundVault: await fundVault.getAddress(),
      SecretSwap: await secretSwap.getAddress(),
      TestTokenA: await testTokenA.getAddress(),
      TestTokenB: await testTokenB.getAddress()
    },
    config: {
      platformFeeRate: platformFeeRate,
      feeCollector: feeCollector,
      tradingPairId: pairId
    }
  };

  const fs = require('fs');
  const path = require('path');
  
  // Ensure deployments directory exists
  const deploymentsDir = path.join(__dirname, '../deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  
  // Save deployment info
  const filename = `deployment-${hre.network.name}-${Date.now()}.json`;
  fs.writeFileSync(
    path.join(deploymentsDir, filename),
    JSON.stringify(deploymentInfo, null, 2)
  );
  
  console.log(`\n💾 Deployment info saved to: deployments/${filename}`);

  console.log("\n🎉 Deployment completed successfully!");
  console.log("\n🌐 Next steps:");
  console.log("1. Update frontend configuration with contract addresses");
  console.log("2. Verify contracts on Etherscan (if on public network)");
  console.log("3. Test the application at http://localhost:3017");
  console.log("4. Run comprehensive tests with: npm test");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });