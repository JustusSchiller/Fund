// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/**
 * @title ZamaFHEConfig
 * @notice Configuration contract for Zama FHE integration on Sepolia testnet
 * @dev Contains all the official Zama FHE contract addresses and utilities
 */
contract ZamaFHEConfig {
    
    // Zama FHE Contract Addresses on Sepolia Testnet
    address public constant FHEVM_EXECUTOR = 0x848B0066793BcC60346Da1F49049357399B8D595;
    address public constant ACL_CONTRACT = 0x687820221192C5B662b25367F70076A37bc79b6c;
    address public constant HCU_LIMIT_CONTRACT = 0x594BB474275918AF9609814E68C61B1587c5F838;
    address public constant KMS_VERIFIER = 0x1364cBBf2cDF5032C47d8226a6f6FBD2AFCDacAC;
    address public constant INPUT_VERIFIER = 0xbc91f3daD1A5F19F8390c400196e58073B6a0BC4;
    address public constant DECRYPTION_ORACLE = 0xa02Cda4Ca3a71D7C46997716F4283aa851C28812;
    address public constant DECRYPTION_ADDRESS = 0xb6E160B1ff80D67Bfe90A85eE06Ce0A2613607D1;
    address public constant INPUT_VERIFICATION_ADDRESS = 0x7048C39f048125eDa9d678AEbaDfB22F7900a29F;
    
    // Zama Relayer URL
    string public constant RELAYER_URL = "https://relayer.testnet.zama.cloud";
    
    // Network Information
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    
    // Events
    event FHEContractConfigured(string contractName, address contractAddress);
    
    constructor() {
        emit FHEContractConfigured("FHEVM_EXECUTOR", FHEVM_EXECUTOR);
        emit FHEContractConfigured("ACL_CONTRACT", ACL_CONTRACT);
        emit FHEContractConfigured("HCU_LIMIT_CONTRACT", HCU_LIMIT_CONTRACT);
        emit FHEContractConfigured("KMS_VERIFIER", KMS_VERIFIER);
        emit FHEContractConfigured("INPUT_VERIFIER", INPUT_VERIFIER);
        emit FHEContractConfigured("DECRYPTION_ORACLE", DECRYPTION_ORACLE);
        emit FHEContractConfigured("DECRYPTION_ADDRESS", DECRYPTION_ADDRESS);
        emit FHEContractConfigured("INPUT_VERIFICATION_ADDRESS", INPUT_VERIFICATION_ADDRESS);
    }
    
    /**
     * @notice Get all FHE contract addresses
     * @return executor Address of FHEVM executor contract
     * @return acl Address of ACL contract
     * @return hcuLimit Address of HCU limit contract
     * @return kmsVerifier Address of KMS verifier contract
     * @return inputVerifier Address of input verifier contract
     * @return decryptionOracle Address of decryption oracle contract
     * @return decryptionAddress Address for decryption operations
     * @return inputVerificationAddress Address for input verification
     */
    function getFHEContracts() 
        external 
        pure 
        returns (
            address executor,
            address acl,
            address hcuLimit,
            address kmsVerifier,
            address inputVerifier,
            address decryptionOracle,
            address decryptionAddress,
            address inputVerificationAddress
        ) 
    {
        return (
            FHEVM_EXECUTOR,
            ACL_CONTRACT,
            HCU_LIMIT_CONTRACT,
            KMS_VERIFIER,
            INPUT_VERIFIER,
            DECRYPTION_ORACLE,
            DECRYPTION_ADDRESS,
            INPUT_VERIFICATION_ADDRESS
        );
    }
    
    /**
     * @notice Check if we're on the correct network for FHE operations
     * @return isValidNetwork True if on Sepolia testnet
     */
    function isValidFHENetwork() external view returns (bool isValidNetwork) {
        return block.chainid == SEPOLIA_CHAIN_ID;
    }
    
    /**
     * @notice Get the relayer URL for FHE operations
     * @return relayerUrl The Zama relayer URL
     */
    function getRelayerUrl() external pure returns (string memory relayerUrl) {
        return RELAYER_URL;
    }
    
    /**
     * @notice Validate that all FHE contracts are properly configured
     * @return isValid True if all contracts have non-zero addresses
     */
    function validateFHESetup() external pure returns (bool isValid) {
        return (
            FHEVM_EXECUTOR != address(0) &&
            ACL_CONTRACT != address(0) &&
            HCU_LIMIT_CONTRACT != address(0) &&
            KMS_VERIFIER != address(0) &&
            INPUT_VERIFIER != address(0) &&
            DECRYPTION_ORACLE != address(0) &&
            DECRYPTION_ADDRESS != address(0) &&
            INPUT_VERIFICATION_ADDRESS != address(0)
        );
    }
}