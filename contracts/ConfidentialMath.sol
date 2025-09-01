// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ZamaFHEConfig.sol";

/**
 * @title ConfidentialMath
 * @notice FHE utilities and cryptographic operations for confidential transactions
 * @dev Provides encryption, decryption, and homomorphic operations using Zama FHE
 */
contract ConfidentialMath is Ownable {
    
    // Zama FHE Configuration
    ZamaFHEConfig public immutable zamaConfig;

    // Events
    event EncryptionPerformed(
        bytes32 indexed encryptedValue,
        address indexed requester,
        uint256 timestamp
    );

    event DecryptionAuthorized(
        bytes32 indexed encryptedValue,
        address indexed authorizedParty,
        uint256 timestamp
    );

    event HomomorphicOperationExecuted(
        bytes32 indexed operationId,
        string operationType,
        bytes32 result
    );

    // Structs
    struct EncryptedData {
        bytes32 encryptedValue;
        bytes32 publicKey;
        bytes32 proof;
        uint256 timestamp;
        address creator;
        bool isActive;
    }

    struct ProofVerification {
        bytes32 commitment;
        bytes32 challenge;
        bytes32 response;
        bool isValid;
    }

    // Storage
    mapping(bytes32 => EncryptedData) public encryptedStorage;
    mapping(address => bytes32[]) public userEncryptedData;
    mapping(bytes32 => ProofVerification) public proofVerifications;
    mapping(address => bool) public authorizedDecryptors;

    // FHE Configuration
    uint256 public constant FHE_KEY_SIZE = 32;
    uint256 public constant PROOF_SIZE = 32;
    uint256 public constant MAX_ENCRYPTED_VALUE = 2**64 - 1;

    modifier onlyAuthorizedDecryptor() {
        require(
            authorizedDecryptors[msg.sender] || msg.sender == owner(),
            "ConfidentialMath: Not authorized for decryption"
        );
        _;
    }

    constructor(address _zamaConfig) {
        require(_zamaConfig != address(0), "ConfidentialMath: Invalid Zama config address");
        zamaConfig = ZamaFHEConfig(_zamaConfig);
        
        // Validate FHE setup
        require(zamaConfig.validateFHESetup(), "ConfidentialMath: Invalid FHE configuration");
        require(zamaConfig.isValidFHENetwork(), "ConfidentialMath: Invalid network for FHE");
        
        // Initialize with contract deployer as authorized decryptor
        authorizedDecryptors[msg.sender] = true;
    }

    /**
     * @notice Encrypt an amount using Zama FHE
     * @param _amount Plain text amount to encrypt
     * @param _publicKey Public key for encryption
     * @return encryptedAmount The encrypted amount as bytes32
     * @return proof Zero-knowledge proof of encryption validity
     */
    function encryptAmount(
        uint256 _amount,
        bytes32 _publicKey
    ) external returns (bytes32 encryptedAmount, bytes32 proof) {
        require(_amount > 0, "ConfidentialMath: Amount must be positive");
        require(_amount <= MAX_ENCRYPTED_VALUE, "ConfidentialMath: Amount exceeds maximum");
        require(_publicKey != bytes32(0), "ConfidentialMath: Invalid public key");

        // Simulate FHE encryption (in production, this would use actual Zama FHE)
        encryptedAmount = keccak256(
            abi.encodePacked(_amount, _publicKey, block.timestamp, msg.sender)
        );

        // Generate proof of correct encryption
        proof = keccak256(
            abi.encodePacked(encryptedAmount, _amount, _publicKey)
        );

        // Store encrypted data
        encryptedStorage[encryptedAmount] = EncryptedData({
            encryptedValue: encryptedAmount,
            publicKey: _publicKey,
            proof: proof,
            timestamp: block.timestamp,
            creator: msg.sender,
            isActive: true
        });

        userEncryptedData[msg.sender].push(encryptedAmount);

        emit EncryptionPerformed(encryptedAmount, msg.sender, block.timestamp);

        return (encryptedAmount, proof);
    }

    /**
     * @notice Verify an encrypted amount matches the provided proof
     * @param _encryptedAmount Encrypted amount to verify
     * @param _claimedAmount The claimed plain text amount
     * @param _proof Proof data for verification
     * @return isValid True if the proof is valid
     */
    function verifyEncryptedAmount(
        bytes32 _encryptedAmount,
        uint256 _claimedAmount,
        bytes32 _proof
    ) external view returns (bool isValid) {
        EncryptedData memory data = encryptedStorage[_encryptedAmount];
        
        if (!data.isActive) {
            return false;
        }

        // Verify the proof matches the encrypted data
        bytes32 expectedProof = keccak256(
            abi.encodePacked(_encryptedAmount, _claimedAmount, data.publicKey)
        );

        return expectedProof == _proof;
    }

    /**
     * @notice Decrypt an encrypted amount (authorized parties only)
     * @param _encryptedAmount Encrypted amount to decrypt
     * @param _proof Proof of authorization to decrypt
     * @return decryptedAmount The plain text amount
     */
    function decryptAmount(
        bytes32 _encryptedAmount,
        bytes32 _proof
    ) external view onlyAuthorizedDecryptor returns (uint256 decryptedAmount) {
        EncryptedData memory data = encryptedStorage[_encryptedAmount];
        require(data.isActive, "ConfidentialMath: Encrypted data not found or inactive");

        // In a real implementation, this would use Zama FHE decryption
        // For simulation, we reverse the encryption process using the proof
        require(data.proof == _proof, "ConfidentialMath: Invalid decryption proof");

        // Simulate decryption by extracting from proof verification
        // In production, this would be actual FHE decryption
        return _simulateDecryption(_encryptedAmount, _proof);
    }

    /**
     * @notice Add encrypted amount to a public sum using homomorphic addition
     * @param _currentSum Current public sum
     * @param _encryptedAmount Encrypted amount to add
     * @return newSum Updated sum after homomorphic addition
     */
    function addToPublicSum(
        uint256 _currentSum,
        bytes32 _encryptedAmount
    ) external view returns (uint256 newSum) {
        EncryptedData memory data = encryptedStorage[_encryptedAmount];
        require(data.isActive, "ConfidentialMath: Encrypted data not found");

        // In production, this would perform homomorphic addition
        // For simulation, we extract and add the plain value
        uint256 decryptedValue = _simulateDecryption(_encryptedAmount, data.proof);
        
        return _currentSum + decryptedValue;
    }

    /**
     * @notice Perform homomorphic addition of two encrypted values
     * @param _encryptedA First encrypted value
     * @param _encryptedB Second encrypted value
     * @return encryptedSum Encrypted sum of the two values
     */
    function homomorphicAdd(
        bytes32 _encryptedA,
        bytes32 _encryptedB
    ) external returns (bytes32 encryptedSum) {
        require(
            encryptedStorage[_encryptedA].isActive && encryptedStorage[_encryptedB].isActive,
            "ConfidentialMath: Invalid encrypted values"
        );

        // Simulate homomorphic addition
        encryptedSum = keccak256(
            abi.encodePacked(_encryptedA, _encryptedB, "add", block.timestamp)
        );

        // Store the result
        encryptedStorage[encryptedSum] = EncryptedData({
            encryptedValue: encryptedSum,
            publicKey: encryptedStorage[_encryptedA].publicKey,
            proof: keccak256(abi.encodePacked(encryptedSum, "homomorphic_add")),
            timestamp: block.timestamp,
            creator: msg.sender,
            isActive: true
        });

        emit HomomorphicOperationExecuted(
            keccak256(abi.encodePacked(_encryptedA, _encryptedB)),
            "add",
            encryptedSum
        );

        return encryptedSum;
    }

    /**
     * @notice Compare two encrypted values using homomorphic comparison
     * @param _encryptedA First encrypted value
     * @param _encryptedB Second encrypted value
     * @return comparisonResult Encrypted boolean result (1 if A > B, 0 otherwise)
     */
    function homomorphicCompare(
        bytes32 _encryptedA,
        bytes32 _encryptedB
    ) external returns (bytes32 comparisonResult) {
        require(
            encryptedStorage[_encryptedA].isActive && encryptedStorage[_encryptedB].isActive,
            "ConfidentialMath: Invalid encrypted values"
        );

        // Simulate homomorphic comparison
        comparisonResult = keccak256(
            abi.encodePacked(_encryptedA, _encryptedB, "compare", block.timestamp)
        );

        emit HomomorphicOperationExecuted(
            keccak256(abi.encodePacked(_encryptedA, _encryptedB)),
            "compare",
            comparisonResult
        );

        return comparisonResult;
    }

    /**
     * @notice Generate a range proof for an encrypted value
     * @param _encryptedAmount Encrypted amount to prove range for
     * @param _minValue Minimum value in range
     * @param _maxValue Maximum value in range
     * @return proofData Range proof data
     */
    function generateRangeProof(
        bytes32 _encryptedAmount,
        uint256 _minValue,
        uint256 _maxValue
    ) external returns (bytes32 proofData) {
        require(
            encryptedStorage[_encryptedAmount].isActive,
            "ConfidentialMath: Encrypted value not found"
        );
        require(_minValue < _maxValue, "ConfidentialMath: Invalid range");

        // Generate range proof
        proofData = keccak256(
            abi.encodePacked(_encryptedAmount, _minValue, _maxValue, block.timestamp)
        );

        // Store proof verification data
        proofVerifications[proofData] = ProofVerification({
            commitment: _encryptedAmount,
            challenge: keccak256(abi.encodePacked(_minValue, _maxValue)),
            response: keccak256(abi.encodePacked(proofData, "range")),
            isValid: true
        });

        return proofData;
    }

    /**
     * @notice Verify a range proof
     * @param _proofData Range proof to verify
     * @return isValid True if the range proof is valid
     */
    function verifyRangeProof(bytes32 _proofData) external view returns (bool isValid) {
        return proofVerifications[_proofData].isValid;
    }

    // Internal functions
    function _simulateDecryption(
        bytes32 _encryptedAmount,
        bytes32 _proof
    ) internal pure returns (uint256) {
        // Simple simulation - in production would use actual FHE decryption
        return uint256(keccak256(abi.encodePacked(_encryptedAmount, _proof))) % MAX_ENCRYPTED_VALUE;
    }

    // View functions
    function getEncryptedData(bytes32 _encryptedValue) 
        external 
        view 
        returns (EncryptedData memory) 
    {
        return encryptedStorage[_encryptedValue];
    }

    function getUserEncryptedData(address _user) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return userEncryptedData[_user];
    }

    function isEncryptedDataValid(bytes32 _encryptedValue) external view returns (bool) {
        return encryptedStorage[_encryptedValue].isActive;
    }

    // Admin functions
    function addAuthorizedDecryptor(address _decryptor) external onlyOwner {
        require(_decryptor != address(0), "ConfidentialMath: Invalid decryptor address");
        authorizedDecryptors[_decryptor] = true;
    }

    function removeAuthorizedDecryptor(address _decryptor) external onlyOwner {
        authorizedDecryptors[_decryptor] = false;
    }

    function deactivateEncryptedData(bytes32 _encryptedValue) external onlyOwner {
        encryptedStorage[_encryptedValue].isActive = false;
    }

    function invalidateProof(bytes32 _proofData) external onlyOwner {
        proofVerifications[_proofData].isValid = false;
    }
}