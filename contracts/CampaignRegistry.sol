// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title CampaignRegistry
 * @notice Registry for managing and verifying fundraising campaigns
 * @dev Handles campaign metadata, verification status, and reputation scoring
 */
contract CampaignRegistry is Ownable {
    using Counters for Counters.Counter;

    struct CampaignProfile {
        uint256 campaignId;
        address creator;
        string metadataURI;
        bool isVerified;
        bool isActive;
        uint256 reputationScore;
        uint256 registrationTime;
        VerificationLevel verificationLevel;
        string[] tags;
    }

    enum VerificationLevel { 
        Unverified, 
        BasicKYC, 
        FullKYC, 
        Audited, 
        Premium 
    }

    // Events
    event CampaignRegistered(
        uint256 indexed campaignId,
        address indexed creator,
        string metadataURI,
        uint256 timestamp
    );

    event CampaignVerified(
        uint256 indexed campaignId,
        VerificationLevel level,
        address verifier
    );

    event ReputationUpdated(
        uint256 indexed campaignId,
        uint256 previousScore,
        uint256 newScore
    );

    event MetadataUpdated(
        uint256 indexed campaignId,
        string newMetadataURI
    );

    // Storage
    mapping(uint256 => CampaignProfile) public campaignProfiles;
    mapping(address => uint256[]) public creatorCampaigns;
    mapping(address => bool) public authorizedVerifiers;
    mapping(VerificationLevel => uint256) public verificationCosts;

    uint256[] public allCampaignIds;
    Counters.Counter private campaignIdCounter;

    // Configuration
    uint256 public constant MAX_REPUTATION_SCORE = 1000;
    uint256 public constant INITIAL_REPUTATION = 100;

    modifier onlyVerifier() {
        require(
            authorizedVerifiers[msg.sender] || msg.sender == owner(),
            "CampaignRegistry: Not authorized verifier"
        );
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(
            campaignProfiles[_campaignId].campaignId != 0,
            "CampaignRegistry: Campaign does not exist"
        );
        _;
    }

    constructor() {
        // Set initial verification costs (in wei)
        verificationCosts[VerificationLevel.BasicKYC] = 0.01 ether;
        verificationCosts[VerificationLevel.FullKYC] = 0.05 ether;
        verificationCosts[VerificationLevel.Audited] = 0.1 ether;
        verificationCosts[VerificationLevel.Premium] = 0.25 ether;
    }

    /**
     * @notice Register a new campaign in the registry
     * @param _campaignId Unique campaign identifier
     * @param _creator Address of the campaign creator
     * @param _metadataURI IPFS URI containing campaign metadata
     */
    function registerCampaign(
        uint256 _campaignId,
        address _creator,
        string memory _metadataURI
    ) external {
        require(
            campaignProfiles[_campaignId].campaignId == 0,
            "CampaignRegistry: Campaign already registered"
        );
        require(_creator != address(0), "CampaignRegistry: Invalid creator address");
        require(bytes(_metadataURI).length > 0, "CampaignRegistry: Empty metadata URI");

        campaignProfiles[_campaignId] = CampaignProfile({
            campaignId: _campaignId,
            creator: _creator,
            metadataURI: _metadataURI,
            isVerified: false,
            isActive: true,
            reputationScore: INITIAL_REPUTATION,
            registrationTime: block.timestamp,
            verificationLevel: VerificationLevel.Unverified,
            tags: new string[](0)
        });

        creatorCampaigns[_creator].push(_campaignId);
        allCampaignIds.push(_campaignId);

        emit CampaignRegistered(_campaignId, _creator, _metadataURI, block.timestamp);
    }

    /**
     * @notice Update campaign metadata
     * @param _campaignId Campaign to update
     * @param _newMetadataURI New metadata URI
     */
    function updateCampaignMetadata(
        uint256 _campaignId,
        string memory _newMetadataURI
    ) external campaignExists(_campaignId) {
        CampaignProfile storage profile = campaignProfiles[_campaignId];
        require(
            msg.sender == profile.creator || msg.sender == owner(),
            "CampaignRegistry: Not authorized to update"
        );
        require(bytes(_newMetadataURI).length > 0, "CampaignRegistry: Empty metadata URI");

        profile.metadataURI = _newMetadataURI;

        emit MetadataUpdated(_campaignId, _newMetadataURI);
    }

    /**
     * @notice Verify a campaign with specific verification level
     * @param _campaignId Campaign to verify
     * @param _level Verification level to assign
     */
    function verifyCampaign(
        uint256 _campaignId,
        VerificationLevel _level
    ) external payable onlyVerifier campaignExists(_campaignId) {
        require(_level != VerificationLevel.Unverified, "CampaignRegistry: Invalid verification level");
        
        if (msg.sender != owner()) {
            require(msg.value >= verificationCosts[_level], "CampaignRegistry: Insufficient verification fee");
        }

        CampaignProfile storage profile = campaignProfiles[_campaignId];
        profile.isVerified = true;
        profile.verificationLevel = _level;

        // Boost reputation based on verification level
        uint256 reputationBoost = uint256(_level) * 50;
        if (profile.reputationScore + reputationBoost <= MAX_REPUTATION_SCORE) {
            profile.reputationScore += reputationBoost;
        } else {
            profile.reputationScore = MAX_REPUTATION_SCORE;
        }

        emit CampaignVerified(_campaignId, _level, msg.sender);
    }

    /**
     * @notice Update campaign reputation score
     * @param _campaignId Campaign to update
     * @param _newScore New reputation score (0-1000)
     */
    function updateReputation(
        uint256 _campaignId,
        uint256 _newScore
    ) external onlyVerifier campaignExists(_campaignId) {
        require(_newScore <= MAX_REPUTATION_SCORE, "CampaignRegistry: Score exceeds maximum");

        CampaignProfile storage profile = campaignProfiles[_campaignId];
        uint256 previousScore = profile.reputationScore;
        profile.reputationScore = _newScore;

        emit ReputationUpdated(_campaignId, previousScore, _newScore);
    }

    /**
     * @notice Add tags to a campaign
     * @param _campaignId Campaign to tag
     * @param _tags Array of tags to add
     */
    function addCampaignTags(
        uint256 _campaignId,
        string[] memory _tags
    ) external campaignExists(_campaignId) {
        CampaignProfile storage profile = campaignProfiles[_campaignId];
        require(
            msg.sender == profile.creator || msg.sender == owner(),
            "CampaignRegistry: Not authorized to add tags"
        );

        for (uint256 i = 0; i < _tags.length; i++) {
            profile.tags.push(_tags[i]);
        }
    }

    /**
     * @notice Deactivate a campaign
     * @param _campaignId Campaign to deactivate
     */
    function deactivateCampaign(uint256 _campaignId) external campaignExists(_campaignId) {
        CampaignProfile storage profile = campaignProfiles[_campaignId];
        require(
            msg.sender == profile.creator || msg.sender == owner(),
            "CampaignRegistry: Not authorized to deactivate"
        );

        profile.isActive = false;
    }

    // View functions
    function getCampaignProfile(uint256 _campaignId) 
        external 
        view 
        returns (CampaignProfile memory) 
    {
        return campaignProfiles[_campaignId];
    }

    function getCreatorCampaigns(address _creator) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return creatorCampaigns[_creator];
    }

    function getAllCampaignIds() external view returns (uint256[] memory) {
        return allCampaignIds;
    }

    function getVerifiedCampaigns() external view returns (uint256[] memory) {
        uint256[] memory verifiedCampaigns = new uint256[](allCampaignIds.length);
        uint256 count = 0;

        for (uint256 i = 0; i < allCampaignIds.length; i++) {
            if (campaignProfiles[allCampaignIds[i]].isVerified) {
                verifiedCampaigns[count] = allCampaignIds[i];
                count++;
            }
        }

        // Resize array to actual count
        assembly {
            mstore(verifiedCampaigns, count)
        }

        return verifiedCampaigns;
    }

    function getCampaignsByReputation(uint256 _minScore) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256[] memory highRepCampaigns = new uint256[](allCampaignIds.length);
        uint256 count = 0;

        for (uint256 i = 0; i < allCampaignIds.length; i++) {
            if (campaignProfiles[allCampaignIds[i]].reputationScore >= _minScore) {
                highRepCampaigns[count] = allCampaignIds[i];
                count++;
            }
        }

        // Resize array to actual count
        assembly {
            mstore(highRepCampaigns, count)
        }

        return highRepCampaigns;
    }

    function getCampaignTags(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (string[] memory) 
    {
        return campaignProfiles[_campaignId].tags;
    }

    // Admin functions
    function addVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "CampaignRegistry: Invalid verifier address");
        authorizedVerifiers[_verifier] = true;
    }

    function removeVerifier(address _verifier) external onlyOwner {
        authorizedVerifiers[_verifier] = false;
    }

    function setVerificationCost(VerificationLevel _level, uint256 _cost) external onlyOwner {
        verificationCosts[_level] = _cost;
    }

    function withdrawFees() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}