// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestToken
 * @notice ERC20 token for testing the FundVault and SecretSwap contracts
 * @dev Simple ERC20 implementation with minting capabilities for testing
 */
contract TestToken is ERC20, Ownable {
    
    uint8 private _decimals;
    uint256 public constant MAX_SUPPLY = 1000000000 * 10**18; // 1 billion tokens
    
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _tokenDecimals,
        uint256 _initialSupply
    ) ERC20(_name, _symbol) {
        _decimals = _tokenDecimals;
        
        if (_initialSupply > 0) {
            require(_initialSupply <= MAX_SUPPLY, "TestToken: Initial supply exceeds maximum");
            _mint(msg.sender, _initialSupply);
        }
    }

    /**
     * @notice Returns the number of decimals used for token amounts
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Mint new tokens to a specified address
     * @param _to Address to receive the minted tokens
     * @param _amount Amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "TestToken: Cannot mint to zero address");
        require(_amount > 0, "TestToken: Amount must be greater than zero");
        require(totalSupply() + _amount <= MAX_SUPPLY, "TestToken: Would exceed maximum supply");
        
        _mint(_to, _amount);
        
        emit TokensMinted(_to, _amount);
    }

    /**
     * @notice Burn tokens from a specified address
     * @param _from Address to burn tokens from
     * @param _amount Amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external onlyOwner {
        require(_from != address(0), "TestToken: Cannot burn from zero address");
        require(_amount > 0, "TestToken: Amount must be greater than zero");
        require(balanceOf(_from) >= _amount, "TestToken: Insufficient balance to burn");
        
        _burn(_from, _amount);
        
        emit TokensBurned(_from, _amount);
    }

    /**
     * @notice Allow users to burn their own tokens
     * @param _amount Amount of tokens to burn
     */
    function burnSelf(uint256 _amount) external {
        require(_amount > 0, "TestToken: Amount must be greater than zero");
        require(balanceOf(msg.sender) >= _amount, "TestToken: Insufficient balance");
        
        _burn(msg.sender, _amount);
        
        emit TokensBurned(msg.sender, _amount);
    }

    /**
     * @notice Batch mint tokens to multiple addresses
     * @param _recipients Array of recipient addresses
     * @param _amounts Array of amounts to mint
     */
    function batchMint(address[] calldata _recipients, uint256[] calldata _amounts) 
        external 
        onlyOwner 
    {
        require(_recipients.length == _amounts.length, "TestToken: Arrays length mismatch");
        require(_recipients.length > 0, "TestToken: Empty arrays");
        
        uint256 totalMintAmount = 0;
        
        // Calculate total amount to check against max supply
        for (uint256 i = 0; i < _amounts.length; i++) {
            require(_recipients[i] != address(0), "TestToken: Cannot mint to zero address");
            require(_amounts[i] > 0, "TestToken: Amount must be greater than zero");
            totalMintAmount += _amounts[i];
        }
        
        require(
            totalSupply() + totalMintAmount <= MAX_SUPPLY, 
            "TestToken: Batch mint would exceed maximum supply"
        );
        
        // Mint tokens to each recipient
        for (uint256 i = 0; i < _recipients.length; i++) {
            _mint(_recipients[i], _amounts[i]);
            emit TokensMinted(_recipients[i], _amounts[i]);
        }
    }

    /**
     * @notice Airdrop tokens to multiple addresses with the same amount
     * @param _recipients Array of recipient addresses
     * @param _amount Amount of tokens to send to each recipient
     */
    function airdrop(address[] calldata _recipients, uint256 _amount) external onlyOwner {
        require(_recipients.length > 0, "TestToken: Empty recipients array");
        require(_amount > 0, "TestToken: Amount must be greater than zero");
        
        uint256 totalMintAmount = _recipients.length * _amount;
        require(
            totalSupply() + totalMintAmount <= MAX_SUPPLY,
            "TestToken: Airdrop would exceed maximum supply"
        );
        
        for (uint256 i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0), "TestToken: Cannot airdrop to zero address");
            _mint(_recipients[i], _amount);
            emit TokensMinted(_recipients[i], _amount);
        }
    }

    /**
     * @notice Get basic token information
     * @return Token name, symbol, decimals, and total supply
     */
    function getTokenInfo() external view returns (
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        uint256 tokenTotalSupply,
        uint256 maxSupply
    ) {
        return (name(), symbol(), decimals(), totalSupply(), MAX_SUPPLY);
    }

    /**
     * @notice Check if an address has sufficient balance for an amount
     * @param _account Address to check
     * @param _amount Amount to verify
     * @return True if the account has sufficient balance
     */
    function hasSufficientBalance(address _account, uint256 _amount) 
        external 
        view 
        returns (bool) 
    {
        return balanceOf(_account) >= _amount;
    }

    /**
     * @notice Get the remaining mintable supply
     * @return Amount of tokens that can still be minted
     */
    function remainingMintableSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }

    /**
     * @notice Emergency function to recover accidentally sent tokens
     * @param _tokenAddress Address of the token to recover
     * @param _amount Amount of tokens to recover
     */
    function emergencyTokenRecovery(address _tokenAddress, uint256 _amount) 
        external 
        onlyOwner 
    {
        require(_tokenAddress != address(this), "TestToken: Cannot recover own tokens");
        require(_tokenAddress != address(0), "TestToken: Invalid token address");
        
        IERC20(_tokenAddress).transfer(owner(), _amount);
    }

    /**
     * @notice Emergency function to recover accidentally sent Ether
     */
    function emergencyEtherRecovery() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Optional: Allow contract to receive Ether
    receive() external payable {}
    fallback() external payable {}
}