const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("FundVault", function () {
  async function deployFundVaultFixture() {
    const [owner, feeCollector, campaignCreator, investor1, investor2] = await ethers.getSigners();

    // Deploy ConfidentialMath
    const ConfidentialMath = await ethers.getContractFactory("ConfidentialMath");
    const confidentialMath = await ConfidentialMath.deploy();

    // Deploy CampaignRegistry
    const CampaignRegistry = await ethers.getContractFactory("CampaignRegistry");
    const campaignRegistry = await CampaignRegistry.deploy();

    // Deploy FundVault
    const platformFeeRate = 250; // 2.5%
    const FundVault = await ethers.getContractFactory("FundVault");
    const fundVault = await FundVault.deploy(
      await campaignRegistry.getAddress(),
      await confidentialMath.getAddress(),
      platformFeeRate,
      feeCollector.address
    );

    // Deploy test token
    const TestToken = await ethers.getContractFactory("TestToken");
    const rewardToken = await TestToken.deploy(
      "RewardToken",
      "RWT",
      18,
      ethers.parseEther("1000000")
    );

    // Setup permissions
    await confidentialMath.addAuthorizedDecryptor(await fundVault.getAddress());
    await campaignRegistry.addVerifier(owner.address);

    return {
      fundVault,
      campaignRegistry,
      confidentialMath,
      rewardToken,
      owner,
      feeCollector,
      campaignCreator,
      investor1,
      investor2,
      platformFeeRate
    };
  }

  describe("Deployment", function () {
    it("Should deploy with correct parameters", async function () {
      const { fundVault, campaignRegistry, confidentialMath, feeCollector, platformFeeRate } = 
        await loadFixture(deployFundVaultFixture);

      expect(await fundVault.campaignRegistry()).to.equal(await campaignRegistry.getAddress());
      expect(await fundVault.confidentialMath()).to.equal(await confidentialMath.getAddress());
      expect(await fundVault.platformFeeRate()).to.equal(platformFeeRate);
      expect(await fundVault.feeCollector()).to.equal(feeCollector.address);
    });

    it("Should initialize campaign counter to 0", async function () {
      const { fundVault } = await loadFixture(deployFundVaultFixture);
      expect(await fundVault.campaignCounter()).to.equal(0);
    });

    it("Should set owner correctly", async function () {
      const { fundVault, owner } = await loadFixture(deployFundVaultFixture);
      expect(await fundVault.owner()).to.equal(owner.address);
    });
  });

  describe("Campaign Creation", function () {
    it("Should create a new campaign successfully", async function () {
      const { fundVault, rewardToken, campaignCreator } = await loadFixture(deployFundVaultFixture);

      const totalTokenSupply = ethers.parseEther("100000");
      const fundingGoal = ethers.parseEther("100");
      const tokenExchangeRate = ethers.parseEther("1000"); // 1000 tokens per ETH
      const duration = 30 * 24 * 60 * 60; // 30 days
      const minInvestment = ethers.parseEther("0.1");
      const maxInvestment = ethers.parseEther("10");
      const metadata = "ipfs://QmTestCampaignMetadata";

      // Transfer tokens to campaign creator
      await rewardToken.transfer(campaignCreator.address, totalTokenSupply);
      
      // Approve FundVault to spend tokens
      await rewardToken.connect(campaignCreator).approve(await fundVault.getAddress(), totalTokenSupply);

      const tx = await fundVault.connect(campaignCreator).launchCampaign(
        await rewardToken.getAddress(),
        totalTokenSupply,
        fundingGoal,
        tokenExchangeRate,
        duration,
        minInvestment,
        maxInvestment,
        metadata
      );

      await expect(tx)
        .to.emit(fundVault, "CampaignLaunched")
        .withArgs(1, campaignCreator.address, fundingGoal, anyValue, anyValue);

      const campaign = await fundVault.getCampaignDetails(1);
      expect(campaign.campaignCreator).to.equal(campaignCreator.address);
      expect(campaign.rewardToken).to.equal(await rewardToken.getAddress());
      expect(campaign.fundingGoal).to.equal(fundingGoal);
      expect(campaign.isLive).to.be.true;
    });

    it("Should increment campaign counter", async function () {
      const { fundVault, rewardToken, campaignCreator } = await loadFixture(deployFundVaultFixture);

      // Create first campaign
      await setupBasicCampaign(fundVault, rewardToken, campaignCreator);
      expect(await fundVault.campaignCounter()).to.equal(1);

      // Create second campaign  
      await setupBasicCampaign(fundVault, rewardToken, campaignCreator);
      expect(await fundVault.campaignCounter()).to.equal(2);
    });

    it("Should revert with invalid parameters", async function () {
      const { fundVault, campaignCreator } = await loadFixture(deployFundVaultFixture);

      const duration = 30 * 24 * 60 * 60; // 30 days
      const minInvestment = ethers.parseEther("0.1");
      const maxInvestment = ethers.parseEther("10");
      const metadata = "ipfs://QmTestCampaignMetadata";

      // Invalid token address
      await expect(
        fundVault.connect(campaignCreator).launchCampaign(
          ethers.ZeroAddress,
          ethers.parseEther("100000"),
          ethers.parseEther("100"),
          ethers.parseEther("1000"),
          duration,
          minInvestment,
          maxInvestment,
          metadata
        )
      ).to.be.revertedWith("FundVault: Invalid token address");

      // Invalid funding goal
      await expect(
        fundVault.connect(campaignCreator).launchCampaign(
          "0x742d35Cc6634C0532925a3b8D0CDAD5d4F4b8f32", // dummy address
          ethers.parseEther("100000"),
          0, // Invalid funding goal
          ethers.parseEther("1000"),
          duration,
          minInvestment,
          maxInvestment,
          metadata
        )
      ).to.be.revertedWith("FundVault: Invalid funding goal");
    });
  });

  describe("Confidential Investments", function () {
    it("Should accept confidential investment", async function () {
      const { fundVault, rewardToken, campaignCreator, investor1, confidentialMath } = 
        await loadFixture(deployFundVaultFixture);

      const campaignId = await setupBasicCampaign(fundVault, rewardToken, campaignCreator);
      
      // Generate encrypted amount
      const investmentAmount = ethers.parseEther("1");
      const publicKey = ethers.randomBytes(32);
      
      const [encryptedAmount, proof] = await confidentialMath.encryptAmount(
        investmentAmount,
        publicKey
      );

      const tx = await fundVault.connect(investor1).makeConfidentialInvestment(
        campaignId,
        encryptedAmount,
        proof,
        { value: investmentAmount }
      );

      await expect(tx)
        .to.emit(fundVault, "ConfidentialContribution")
        .withArgs(campaignId, investor1.address, encryptedAmount, anyValue);
    });

    it("Should reject investment below minimum", async function () {
      const { fundVault, rewardToken, campaignCreator, investor1, confidentialMath } = 
        await loadFixture(deployFundVaultFixture);

      const campaignId = await setupBasicCampaign(fundVault, rewardToken, campaignCreator);
      
      const investmentAmount = ethers.parseEther("0.05"); // Below minimum
      const publicKey = ethers.randomBytes(32);
      
      const [encryptedAmount, proof] = await confidentialMath.encryptAmount(
        investmentAmount,
        publicKey
      );

      await expect(
        fundVault.connect(investor1).makeConfidentialInvestment(
          campaignId,
          encryptedAmount,
          proof,
          { value: investmentAmount }
        )
      ).to.be.revertedWith("FundVault: Below minimum investment");
    });

    it("Should reject investment above maximum", async function () {
      const { fundVault, rewardToken, campaignCreator, investor1, confidentialMath } = 
        await loadFixture(deployFundVaultFixture);

      const campaignId = await setupBasicCampaign(fundVault, rewardToken, campaignCreator);
      
      const investmentAmount = ethers.parseEther("15"); // Above maximum
      const publicKey = ethers.randomBytes(32);
      
      const [encryptedAmount, proof] = await confidentialMath.encryptAmount(
        investmentAmount,
        publicKey
      );

      await expect(
        fundVault.connect(investor1).makeConfidentialInvestment(
          campaignId,
          encryptedAmount,
          proof,
          { value: investmentAmount }
        )
      ).to.be.revertedWith("FundVault: Exceeds maximum investment");
    });
  });

  describe("Token Withdrawal", function () {
    it("Should allow token withdrawal after successful campaign", async function () {
      const { fundVault, rewardToken, campaignCreator, investor1, confidentialMath } = 
        await loadFixture(deployFundVaultFixture);

      const campaignId = await setupBasicCampaign(fundVault, rewardToken, campaignCreator);
      
      // Make sufficient investment to reach goal
      const investmentAmount = ethers.parseEther("50");
      const publicKey = ethers.randomBytes(32);
      
      const [encryptedAmount, proof] = await confidentialMath.encryptAmount(
        investmentAmount,
        publicKey
      );

      await fundVault.connect(investor1).makeConfidentialInvestment(
        campaignId,
        encryptedAmount,
        proof,
        { value: investmentAmount }
      );

      // Fast forward past campaign end
      await ethers.provider.send("evm_increaseTime", [31 * 24 * 60 * 60]); // 31 days
      await ethers.provider.send("evm_mine");

      // Check if campaign is successful
      const campaign = await fundVault.getCampaignDetails(campaignId);
      expect(campaign.goalAchieved).to.be.true;

      // Withdraw tokens
      const initialBalance = await rewardToken.balanceOf(investor1.address);
      
      await fundVault.connect(investor1).withdrawTokens(campaignId);
      
      const finalBalance = await rewardToken.balanceOf(investor1.address);
      expect(finalBalance).to.be.gt(initialBalance);
    });

    it("Should reject withdrawal from unsuccessful campaign", async function () {
      const { fundVault, rewardToken, campaignCreator, investor1, confidentialMath } = 
        await loadFixture(deployFundVaultFixture);

      const campaignId = await setupBasicCampaign(fundVault, rewardToken, campaignCreator);
      
      // Make small investment (won't reach goal)
      const investmentAmount = ethers.parseEther("1");
      const publicKey = ethers.randomBytes(32);
      
      const [encryptedAmount, proof] = await confidentialMath.encryptAmount(
        investmentAmount,
        publicKey
      );

      await fundVault.connect(investor1).makeConfidentialInvestment(
        campaignId,
        encryptedAmount,
        proof,
        { value: investmentAmount }
      );

      // Fast forward past campaign end
      await ethers.provider.send("evm_increaseTime", [31 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine");

      await expect(
        fundVault.connect(investor1).withdrawTokens(campaignId)
      ).to.be.revertedWith("FundVault: Campaign not successful");
    });
  });

  describe("Emergency Refunds", function () {
    it("Should process emergency refund for failed campaign", async function () {
      const { fundVault, rewardToken, campaignCreator, investor1, confidentialMath } = 
        await loadFixture(deployFundVaultFixture);

      const campaignId = await setupBasicCampaign(fundVault, rewardToken, campaignCreator);
      
      const investmentAmount = ethers.parseEther("1");
      const publicKey = ethers.randomBytes(32);
      
      const [encryptedAmount, proof] = await confidentialMath.encryptAmount(
        investmentAmount,
        publicKey
      );

      await fundVault.connect(investor1).makeConfidentialInvestment(
        campaignId,
        encryptedAmount,
        proof,
        { value: investmentAmount }
      );

      // Fast forward past campaign end
      await ethers.provider.send("evm_increaseTime", [31 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine");

      const initialBalance = await ethers.provider.getBalance(investor1.address);
      
      const tx = await fundVault.connect(investor1).processEmergencyRefund(campaignId);
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;
      
      const finalBalance = await ethers.provider.getBalance(investor1.address);
      
      // Should receive refund minus gas fees
      expect(finalBalance).to.be.gt(initialBalance - gasUsed);
    });
  });

  describe("Admin Functions", function () {
    it("Should allow owner to set platform fee rate", async function () {
      const { fundVault, owner } = await loadFixture(deployFundVaultFixture);

      const newFeeRate = 500; // 5%
      await fundVault.connect(owner).setPlatformFeeRate(newFeeRate);
      
      expect(await fundVault.platformFeeRate()).to.equal(newFeeRate);
    });

    it("Should reject fee rate above maximum", async function () {
      const { fundVault, owner } = await loadFixture(deployFundVaultFixture);

      const invalidFeeRate = 1100; // 11% (above 10% max)
      
      await expect(
        fundVault.connect(owner).setPlatformFeeRate(invalidFeeRate)
      ).to.be.revertedWith("FundVault: Fee rate too high");
    });

    it("Should allow pausing and unpausing", async function () {
      const { fundVault, owner } = await loadFixture(deployFundVaultFixture);

      await fundVault.connect(owner).pause();
      expect(await fundVault.paused()).to.be.true;

      await fundVault.connect(owner).unpause();
      expect(await fundVault.paused()).to.be.false;
    });
  });

  // Helper function to setup a basic campaign
  async function setupBasicCampaign(fundVault, rewardToken, campaignCreator) {
    const totalTokenSupply = ethers.parseEther("100000");
    const fundingGoal = ethers.parseEther("100");
    const tokenExchangeRate = ethers.parseEther("1000");
    const duration = 30 * 24 * 60 * 60; // 30 days
    const minInvestment = ethers.parseEther("0.1");
    const maxInvestment = ethers.parseEther("10");
    const metadata = "ipfs://QmTestCampaignMetadata";

    await rewardToken.transfer(campaignCreator.address, totalTokenSupply);
    await rewardToken.connect(campaignCreator).approve(await fundVault.getAddress(), totalTokenSupply);

    const tx = await fundVault.connect(campaignCreator).launchCampaign(
      await rewardToken.getAddress(),
      totalTokenSupply,
      fundingGoal,
      tokenExchangeRate,
      duration,
      minInvestment,
      maxInvestment,
      metadata
    );

    const receipt = await tx.wait();
    const event = receipt.logs.find(log => log.fragment?.name === 'CampaignLaunched');
    return event.args[0]; // campaignId
  }

  // Custom matcher for anyValue
  const anyValue = ethers.isAddress;
});