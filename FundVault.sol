// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./CampaignRegistry.sol";
import "./ConfidentialMath.sol";

/**
 * @title FundVault
 * @notice Confidential fundraising vault using Zama FHE for private investment tracking
 * @dev Enables secret participation in decentralized fundraising with encrypted amounts
 */
contract FundVault is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    // Investment campaign structure
    struct InvestmentCampaign {
        uint256 campaignId;
        address campaignCreator;
        address rewardToken;
        uint256 totalTokenSupply;
        uint256 fundingGoal;
        uint256 publicRaisedAmount; // Public aggregated amount from FHE operations
        uint256 tokenExchangeRate;
        uint256 campaignStart;
        uint256 campaignEnd;
        uint256 minimumInvestment;
        uint256 maximumInvestment;
        bool isLive;
        bool goalAchieved;
        string campaignMetadata;
        CampaignState state;
    }

    enum CampaignState { 
        Draft, 
        Live, 
        Successful, 
        Failed, 
        Finalized 
    }

    // Encrypted investment record
    struct ConfidentialInvestment {
        bytes32 encryptedContribution;
        address contributor;
        uint256 campaignId;
        uint256 investmentTime;
        bool tokensWithdrawn;
        bytes32 proofData; // Zero-knowledge proof data
    }

    // Events
    event CampaignLaunched(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 fundingGoal,
        uint256 startTime,
        uint256 endTime
    );

    event ConfidentialContribution(
        uint256 indexed campaignId,
        address indexed contributor,
        bytes32 encryptedAmount,
        uint256 timestamp
    );

    event CampaignSuccessful(
        uint256 indexed campaignId,
        uint256 totalRaised,
        uint256 participantCount
    );

    event TokensWithdrawn(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 tokenAmount
    );

    event EmergencyRefundProcessed(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 refundAmount
    );

    // Storage mappings
    mapping(uint256 => InvestmentCampaign) public campaigns;
    mapping(uint256 => ConfidentialInvestment[]) public campaignContributions;
    mapping(address => uint256[]) public userCampaigns;
    mapping(uint256 => mapping(address => uint256)) public userContributionIndex;
    mapping(address => bool) public authorizedOperators;

    // State variables
    uint256 public campaignCounter;
    uint256 public platformFeeRate; // Basis points (100 = 1%)
    address public feeCollector;
    CampaignRegistry public immutable campaignRegistry;
    ConfidentialMath public immutable confidentialMath;

    // Constants
    uint256 public constant MAX_CAMPAIGN_DURATION = 180 days;
    uint256 public constant MIN_CAMPAIGN_DURATION = 7 days;
    uint256 public constant MAX_PLATFORM_FEE = 1000; // 10%

    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(
            campaigns[_campaignId].campaignCreator == msg.sender,
            "FundVault: Not campaign creator"
        );
        _;
    }

    modifier onlyAuthorizedOperator() {
        require(
            authorizedOperators[msg.sender] || msg.sender == owner(),
            "FundVault: Not authorized operator"
        );
        _;
    }

    modifier validCampaign(uint256 _campaignId) {
        require(
            _campaignId > 0 && _campaignId <= campaignCounter,
            "FundVault: Invalid campaign ID"
        );
        _;
    }

    constructor(
        address _campaignRegistry,
        address _confidentialMath,
        uint256 _platformFeeRate,
        address _feeCollector
    ) {
        require(_campaignRegistry != address(0), "FundVault: Invalid registry address");
        require(_confidentialMath != address(0), "FundVault: Invalid math contract address");
        require(_platformFeeRate <= MAX_PLATFORM_FEE, "FundVault: Fee rate too high");
        require(_feeCollector != address(0), "FundVault: Invalid fee collector");

        campaignRegistry = CampaignRegistry(_campaignRegistry);
        confidentialMath = ConfidentialMath(_confidentialMath);
        platformFeeRate = _platformFeeRate;
        feeCollector = _feeCollector;
        campaignCounter = 0;
    }

    /**
     * @notice Launch a new fundraising campaign
     * @param _rewardToken Address of the token to be distributed to investors
     * @param _totalTokenSupply Total supply of reward tokens for distribution
     * @param _fundingGoal Target funding amount in wei
     * @param _tokenExchangeRate Number of tokens per wei invested
     * @param _duration Campaign duration in seconds
     * @param _minInvestment Minimum investment amount
     * @param _maxInvestment Maximum investment amount per user
     * @param _metadata IPFS hash or URI containing campaign details
     */
    function launchCampaign(
        address _rewardToken,
        uint256 _totalTokenSupply,
        uint256 _fundingGoal,
        uint256 _tokenExchangeRate,
        uint256 _duration,
        uint256 _minInvestment,
        uint256 _maxInvestment,
        string memory _metadata
    ) external nonReentrant whenNotPaused returns (uint256 campaignId) {
        require(_rewardToken != address(0), "FundVault: Invalid token address");
        require(_totalTokenSupply > 0, "FundVault: Invalid token supply");
        require(_fundingGoal > 0, "FundVault: Invalid funding goal");
        require(_tokenExchangeRate > 0, "FundVault: Invalid exchange rate");
        require(
            _duration >= MIN_CAMPAIGN_DURATION && _duration <= MAX_CAMPAIGN_DURATION,
            "FundVault: Invalid campaign duration"
        );
        require(_minInvestment > 0, "FundVault: Invalid minimum investment");
        require(_maxInvestment >= _minInvestment, "FundVault: Invalid maximum investment");

        campaignCounter++;
        campaignId = campaignCounter;

        uint256 campaignStart = block.timestamp;
        uint256 campaignEnd = campaignStart + _duration;

        campaigns[campaignId] = InvestmentCampaign({
            campaignId: campaignId,
            campaignCreator: msg.sender,
            rewardToken: _rewardToken,
            totalTokenSupply: _totalTokenSupply,
            fundingGoal: _fundingGoal,
            publicRaisedAmount: 0,
            tokenExchangeRate: _tokenExchangeRate,
            campaignStart: campaignStart,
            campaignEnd: campaignEnd,
            minimumInvestment: _minInvestment,
            maximumInvestment: _maxInvestment,
            isLive: true,
            goalAchieved: false,
            campaignMetadata: _metadata,
            state: CampaignState.Live
        });

        // Transfer reward tokens to contract for escrow
        IERC20(_rewardToken).safeTransferFrom(msg.sender, address(this), _totalTokenSupply);

        // Register campaign with registry
        campaignRegistry.registerCampaign(campaignId, msg.sender, _metadata);

        emit CampaignLaunched(campaignId, msg.sender, _fundingGoal, campaignStart, campaignEnd);

        return campaignId;
    }

    /**
     * @notice Make a confidential investment using FHE encryption
     * @param _campaignId ID of the campaign to invest in
     * @param _encryptedAmount Encrypted investment amount using Zama FHE
     * @param _proofData Zero-knowledge proof of investment validity
     */
    function makeConfidentialInvestment(
        uint256 _campaignId,
        bytes32 _encryptedAmount,
        bytes32 _proofData
    ) external payable nonReentrant whenNotPaused validCampaign(_campaignId) {
        InvestmentCampaign storage campaign = campaigns[_campaignId];
        
        require(campaign.isLive, "FundVault: Campaign not active");
        require(block.timestamp >= campaign.campaignStart, "FundVault: Campaign not started");
        require(block.timestamp <= campaign.campaignEnd, "FundVault: Campaign ended");
        require(msg.value >= campaign.minimumInvestment, "FundVault: Below minimum investment");
        require(msg.value <= campaign.maximumInvestment, "FundVault: Exceeds maximum investment");

        // Verify encrypted amount matches actual payment using FHE
        require(
            confidentialMath.verifyEncryptedAmount(_encryptedAmount, msg.value, _proofData),
            "FundVault: Invalid encrypted amount proof"
        );

        // Record the confidential investment
        campaignContributions[_campaignId].push(ConfidentialInvestment({
            encryptedContribution: _encryptedAmount,
            contributor: msg.sender,
            campaignId: _campaignId,
            investmentTime: block.timestamp,
            tokensWithdrawn: false,
            proofData: _proofData
        }));

        // Update user's investment tracking
        if (userContributionIndex[_campaignId][msg.sender] == 0) {
            userCampaigns[msg.sender].push(_campaignId);
            userContributionIndex[_campaignId][msg.sender] = campaignContributions[_campaignId].length;
        }

        // Update public raised amount using homomorphic addition
        campaign.publicRaisedAmount = confidentialMath.addToPublicSum(
            campaign.publicRaisedAmount,
            _encryptedAmount
        );

        // Check if funding goal is reached
        if (campaign.publicRaisedAmount >= campaign.fundingGoal && !campaign.goalAchieved) {
            campaign.goalAchieved = true;
            campaign.state = CampaignState.Successful;
            
            emit CampaignSuccessful(
                _campaignId,
                campaign.publicRaisedAmount,
                campaignContributions[_campaignId].length
            );
        }

        emit ConfidentialContribution(_campaignId, msg.sender, _encryptedAmount, block.timestamp);
    }

    /**
     * @notice Withdraw reward tokens after successful campaign
     * @param _campaignId ID of the successful campaign
     */
    function withdrawTokens(uint256 _campaignId) external nonReentrant validCampaign(_campaignId) {
        InvestmentCampaign storage campaign = campaigns[_campaignId];
        require(campaign.goalAchieved, "FundVault: Campaign not successful");
        require(block.timestamp > campaign.campaignEnd, "FundVault: Campaign still active");

        uint256 userIndex = userContributionIndex[_campaignId][msg.sender];
        require(userIndex > 0, "FundVault: No investment found");

        ConfidentialInvestment storage investment = campaignContributions[_campaignId][userIndex - 1];
        require(!investment.tokensWithdrawn, "FundVault: Tokens already withdrawn");
        require(investment.contributor == msg.sender, "FundVault: Not your investment");

        // Decrypt investment amount for token calculation
        uint256 decryptedAmount = confidentialMath.decryptAmount(
            investment.encryptedContribution,
            investment.proofData
        );

        uint256 tokenAmount = (decryptedAmount * campaign.tokenExchangeRate) / 1 ether;
        require(tokenAmount > 0, "FundVault: No tokens to withdraw");

        investment.tokensWithdrawn = true;

        // Transfer reward tokens to investor
        IERC20(campaign.rewardToken).safeTransfer(msg.sender, tokenAmount);

        emit TokensWithdrawn(_campaignId, msg.sender, tokenAmount);
    }

    /**
     * @notice Finalize campaign and transfer raised funds to creator
     * @param _campaignId ID of the campaign to finalize
     */
    function finalizeCampaign(uint256 _campaignId) 
        external 
        nonReentrant 
        onlyCampaignCreator(_campaignId) 
        validCampaign(_campaignId) 
    {
        InvestmentCampaign storage campaign = campaigns[_campaignId];
        require(campaign.goalAchieved, "FundVault: Campaign not successful");
        require(campaign.state == CampaignState.Successful, "FundVault: Invalid campaign state");
        require(block.timestamp > campaign.campaignEnd, "FundVault: Campaign still active");

        campaign.state = CampaignState.Finalized;

        uint256 raisedAmount = campaign.publicRaisedAmount;
        uint256 platformFee = (raisedAmount * platformFeeRate) / 10000;
        uint256 creatorAmount = raisedAmount - platformFee;

        // Transfer platform fee
        if (platformFee > 0) {
            payable(feeCollector).transfer(platformFee);
        }

        // Transfer raised funds to campaign creator
        payable(campaign.campaignCreator).transfer(creatorAmount);
    }

    /**
     * @notice Process emergency refund for failed or cancelled campaigns
     * @param _campaignId ID of the failed campaign
     */
    function processEmergencyRefund(uint256 _campaignId) external nonReentrant validCampaign(_campaignId) {
        InvestmentCampaign storage campaign = campaigns[_campaignId];
        require(
            !campaign.goalAchieved || campaign.state == CampaignState.Failed,
            "FundVault: Campaign not eligible for refund"
        );
        require(block.timestamp > campaign.campaignEnd, "FundVault: Campaign still active");

        uint256 userIndex = userContributionIndex[_campaignId][msg.sender];
        require(userIndex > 0, "FundVault: No investment found");

        ConfidentialInvestment storage investment = campaignContributions[_campaignId][userIndex - 1];
        require(!investment.tokensWithdrawn, "FundVault: Already processed");
        require(investment.contributor == msg.sender, "FundVault: Not your investment");

        // Decrypt investment amount for refund
        uint256 refundAmount = confidentialMath.decryptAmount(
            investment.encryptedContribution,
            investment.proofData
        );

        investment.tokensWithdrawn = true; // Mark as processed to prevent double refund

        // Send refund to investor
        payable(msg.sender).transfer(refundAmount);

        emit EmergencyRefundProcessed(_campaignId, msg.sender, refundAmount);
    }

    // View functions
    function getCampaignDetails(uint256 _campaignId) external view returns (InvestmentCampaign memory) {
        return campaigns[_campaignId];
    }

    function getUserCampaigns(address _user) external view returns (uint256[] memory) {
        return userCampaigns[_user];
    }

    function getCampaignContributionCount(uint256 _campaignId) external view returns (uint256) {
        return campaignContributions[_campaignId].length;
    }

    // Admin functions
    function setPlatformFeeRate(uint256 _newFeeRate) external onlyOwner {
        require(_newFeeRate <= MAX_PLATFORM_FEE, "FundVault: Fee rate too high");
        platformFeeRate = _newFeeRate;
    }

    function setFeeCollector(address _newFeeCollector) external onlyOwner {
        require(_newFeeCollector != address(0), "FundVault: Invalid fee collector");
        feeCollector = _newFeeCollector;
    }

    function addAuthorizedOperator(address _operator) external onlyOwner {
        authorizedOperators[_operator] = true;
    }

    function removeAuthorizedOperator(address _operator) external onlyOwner {
        authorizedOperators[_operator] = false;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Emergency functions
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}