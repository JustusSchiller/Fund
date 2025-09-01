// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title FundVaultOptimized
 * @notice Gas-optimized confidential fundraising vault
 * @dev Simplified version for cost-efficient deployment
 */
contract FundVaultOptimized is ReentrancyGuard, Ownable, Pausable {
    // Packed struct for gas efficiency
    struct Campaign {
        uint128 fundingGoal;      // 16 bytes
        uint128 raisedAmount;     // 16 bytes  
        address creator;          // 20 bytes
        address rewardToken;      // 20 bytes
        uint64 startTime;         // 8 bytes
        uint64 endTime;           // 8 bytes  
        uint32 exchangeRate;      // 4 bytes
        uint16 feeRate;           // 2 bytes
        bool isActive;            // 1 byte
        bool goalReached;         // 1 byte
    }
    
    struct Investment {
        address investor;         // 20 bytes
        uint128 amount;          // 16 bytes
        uint64 timestamp;        // 8 bytes
        bool withdrawn;          // 1 byte
    }
    
    // Events (optimized)
    event CampaignCreated(uint256 indexed id, address indexed creator, uint128 goal);
    event InvestmentMade(uint256 indexed id, address indexed investor, uint128 amount);
    event CampaignSuccessful(uint256 indexed id, uint128 raised);
    event TokensWithdrawn(uint256 indexed id, address indexed investor, uint256 amount);
    
    // Storage
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => Investment[]) public investments;
    mapping(uint256 => mapping(address => uint256)) public investorIndex;
    
    uint256 public campaignCount;
    uint16 public platformFee = 200; // 2% in basis points
    address public feeCollector;
    
    // Constants for gas optimization
    uint64 private constant MIN_DURATION = 7 days;
    uint64 private constant MAX_DURATION = 180 days;
    uint16 private constant MAX_FEE = 1000; // 10%
    
    constructor(address _feeCollector) {
        require(_feeCollector != address(0), "Invalid fee collector");
        feeCollector = _feeCollector;
        campaignCount = 0;
    }
    
    /**
     * @notice Create a new funding campaign (gas optimized)
     */
    function createCampaign(
        address _rewardToken,
        uint128 _fundingGoal,
        uint32 _exchangeRate,
        uint64 _duration
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(_rewardToken != address(0), "Invalid token");
        require(_fundingGoal > 0, "Invalid goal");
        require(_exchangeRate > 0, "Invalid rate");
        require(_duration >= MIN_DURATION && _duration <= MAX_DURATION, "Invalid duration");
        
        uint256 campaignId = ++campaignCount;
        uint64 startTime = uint64(block.timestamp);
        uint64 endTime = startTime + _duration;
        
        campaigns[campaignId] = Campaign({
            fundingGoal: _fundingGoal,
            raisedAmount: 0,
            creator: msg.sender,
            rewardToken: _rewardToken,
            startTime: startTime,
            endTime: endTime,
            exchangeRate: _exchangeRate,
            feeRate: platformFee,
            isActive: true,
            goalReached: false
        });
        
        emit CampaignCreated(campaignId, msg.sender, _fundingGoal);
        return campaignId;
    }
    
    /**
     * @notice Invest in a campaign (gas optimized)
     */
    function invest(uint256 _campaignId) external payable nonReentrant whenNotPaused {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.isActive, "Campaign not active");
        require(block.timestamp >= campaign.startTime, "Not started");
        require(block.timestamp <= campaign.endTime, "Ended");
        require(msg.value > 0, "Invalid amount");
        
        uint128 amount = uint128(msg.value);
        require(campaign.raisedAmount + amount >= campaign.raisedAmount, "Overflow");
        
        // Record investment
        investments[_campaignId].push(Investment({
            investor: msg.sender,
            amount: amount,
            timestamp: uint64(block.timestamp),
            withdrawn: false
        }));
        
        investorIndex[_campaignId][msg.sender] = investments[_campaignId].length;
        campaign.raisedAmount += amount;
        
        // Check if goal reached
        if (!campaign.goalReached && campaign.raisedAmount >= campaign.fundingGoal) {
            campaign.goalReached = true;
            emit CampaignSuccessful(_campaignId, campaign.raisedAmount);
        }
        
        emit InvestmentMade(_campaignId, msg.sender, amount);
    }
    
    /**
     * @notice Withdraw tokens for successful campaign
     */
    function withdrawTokens(uint256 _campaignId) external nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.goalReached, "Goal not reached");
        require(block.timestamp > campaign.endTime, "Still active");
        
        uint256 index = investorIndex[_campaignId][msg.sender];
        require(index > 0, "No investment");
        
        Investment storage investment = investments[_campaignId][index - 1];
        require(!investment.withdrawn, "Already withdrawn");
        require(investment.investor == msg.sender, "Not your investment");
        
        uint256 tokenAmount = (uint256(investment.amount) * campaign.exchangeRate) / 1e18;
        investment.withdrawn = true;
        
        IERC20(campaign.rewardToken).transfer(msg.sender, tokenAmount);
        emit TokensWithdrawn(_campaignId, msg.sender, tokenAmount);
    }
    
    /**
     * @notice Finalize campaign (creator only)
     */
    function finalizeCampaign(uint256 _campaignId) external nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.creator == msg.sender, "Not creator");
        require(campaign.goalReached, "Goal not reached");
        require(block.timestamp > campaign.endTime, "Still active");
        
        campaign.isActive = false;
        
        uint256 totalRaised = campaign.raisedAmount;
        uint256 fee = (totalRaised * campaign.feeRate) / 10000;
        uint256 creatorAmount = totalRaised - fee;
        
        if (fee > 0) {
            payable(feeCollector).transfer(fee);
        }
        payable(campaign.creator).transfer(creatorAmount);
    }
    
    /**
     * @notice Get campaign details
     */
    function getCampaign(uint256 _campaignId) external view returns (Campaign memory) {
        return campaigns[_campaignId];
    }
    
    /**
     * @notice Get investment count for campaign
     */
    function getInvestmentCount(uint256 _campaignId) external view returns (uint256) {
        return investments[_campaignId].length;
    }
    
    /**
     * @notice Admin functions
     */
    function setPlatformFee(uint16 _newFee) external onlyOwner {
        require(_newFee <= MAX_FEE, "Fee too high");
        platformFee = _newFee;
    }
    
    function setFeeCollector(address _newCollector) external onlyOwner {
        require(_newCollector != address(0), "Invalid collector");
        feeCollector = _newCollector;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}