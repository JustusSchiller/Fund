// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./ConfidentialMath.sol";

/**
 * @title SecretSwap
 * @notice Confidential DEX using Zama FHE for private trading
 * @dev Enables secret order placement and execution with encrypted amounts
 */
contract SecretSwap is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    struct TradingPair {
        address tokenA;
        address tokenB;
        bool isActive;
        uint256 totalLiquidity;
        uint256 reserveA;
        uint256 reserveB;
        uint256 feeRate; // Basis points (100 = 1%)
        uint256 creationTime;
    }

    struct SecretOrder {
        uint256 orderId;
        address trader;
        bytes32 pairId;
        bytes32 encryptedAmountIn;
        bytes32 encryptedMinAmountOut;
        address tokenIn;
        address tokenOut;
        uint256 deadline;
        bool isExecuted;
        bool isCancelled;
        bytes32 proofData;
        OrderType orderType;
        uint256 timestamp;
    }

    struct LiquidityPosition {
        uint256 positionId;
        address provider;
        bytes32 pairId;
        bytes32 encryptedLiquidityA;
        bytes32 encryptedLiquidityB;
        uint256 liquidityTokens;
        uint256 timestamp;
        bool isActive;
    }

    enum OrderType { 
        MarketBuy, 
        MarketSell, 
        LimitBuy, 
        LimitSell 
    }

    // Events
    event TradingPairCreated(
        bytes32 indexed pairId,
        address indexed tokenA,
        address indexed tokenB,
        uint256 timestamp
    );

    event SecretOrderPlaced(
        uint256 indexed orderId,
        address indexed trader,
        bytes32 indexed pairId,
        bytes32 encryptedAmountIn,
        uint256 timestamp
    );

    event SecretOrderExecuted(
        uint256 indexed orderId,
        bytes32 indexed pairId,
        bytes32 encryptedAmountOut,
        uint256 timestamp
    );

    event LiquidityAdded(
        uint256 indexed positionId,
        address indexed provider,
        bytes32 indexed pairId,
        uint256 liquidityTokens
    );

    event LiquidityRemoved(
        uint256 indexed positionId,
        address indexed provider,
        bytes32 indexed pairId,
        uint256 liquidityTokens
    );

    // Storage
    mapping(bytes32 => TradingPair) public tradingPairs;
    mapping(uint256 => SecretOrder) public secretOrders;
    mapping(uint256 => LiquidityPosition) public liquidityPositions;
    mapping(address => uint256[]) public userOrders;
    mapping(address => uint256[]) public userPositions;
    mapping(bytes32 => uint256[]) public pairOrders;
    
    bytes32[] public allPairIds;
    uint256 public orderCounter;
    uint256 public positionCounter;
    
    ConfidentialMath public immutable confidentialMath;
    
    // Configuration
    uint256 public constant MAX_FEE_RATE = 1000; // 10%
    uint256 public constant DEFAULT_FEE_RATE = 30; // 0.3%
    uint256 public constant MIN_LIQUIDITY = 1000; // Minimum liquidity for new pairs

    modifier validPair(bytes32 _pairId) {
        require(tradingPairs[_pairId].isActive, "SecretSwap: Invalid trading pair");
        _;
    }

    modifier validOrder(uint256 _orderId) {
        require(_orderId > 0 && _orderId <= orderCounter, "SecretSwap: Invalid order ID");
        require(!secretOrders[_orderId].isExecuted, "SecretSwap: Order already executed");
        require(!secretOrders[_orderId].isCancelled, "SecretSwap: Order cancelled");
        _;
    }

    modifier onlyOrderOwner(uint256 _orderId) {
        require(secretOrders[_orderId].trader == msg.sender, "SecretSwap: Not order owner");
        _;
    }

    constructor(address _confidentialMath) {
        require(_confidentialMath != address(0), "SecretSwap: Invalid ConfidentialMath address");
        confidentialMath = ConfidentialMath(_confidentialMath);
    }

    /**
     * @notice Create a new trading pair
     * @param _tokenA Address of first token
     * @param _tokenB Address of second token
     * @param _feeRate Fee rate in basis points
     * @return pairId Unique identifier for the trading pair
     */
    function createTradingPair(
        address _tokenA,
        address _tokenB,
        uint256 _feeRate
    ) external onlyOwner returns (bytes32 pairId) {
        require(_tokenA != address(0) && _tokenB != address(0), "SecretSwap: Invalid token addresses");
        require(_tokenA != _tokenB, "SecretSwap: Identical token addresses");
        require(_feeRate <= MAX_FEE_RATE, "SecretSwap: Fee rate too high");

        // Create deterministic pair ID
        pairId = keccak256(abi.encodePacked(_tokenA, _tokenB, block.timestamp));
        
        require(!tradingPairs[pairId].isActive, "SecretSwap: Pair already exists");

        tradingPairs[pairId] = TradingPair({
            tokenA: _tokenA,
            tokenB: _tokenB,
            isActive: true,
            totalLiquidity: 0,
            reserveA: 0,
            reserveB: 0,
            feeRate: _feeRate == 0 ? DEFAULT_FEE_RATE : _feeRate,
            creationTime: block.timestamp
        });

        allPairIds.push(pairId);

        emit TradingPairCreated(pairId, _tokenA, _tokenB, block.timestamp);

        return pairId;
    }

    /**
     * @notice Add liquidity to a trading pair with encrypted amounts
     * @param _pairId Trading pair identifier
     * @param _encryptedAmountA Encrypted amount of token A
     * @param _encryptedAmountB Encrypted amount of token B
     * @param _proofData Proof of encrypted amounts validity
     * @return positionId Liquidity position identifier
     */
    function addSecretLiquidity(
        bytes32 _pairId,
        bytes32 _encryptedAmountA,
        bytes32 _encryptedAmountB,
        bytes32 _proofData
    ) external payable nonReentrant whenNotPaused validPair(_pairId) returns (uint256 positionId) {
        TradingPair storage pair = tradingPairs[_pairId];
        
        // Verify encrypted amounts
        require(
            confidentialMath.isEncryptedDataValid(_encryptedAmountA) &&
            confidentialMath.isEncryptedDataValid(_encryptedAmountB),
            "SecretSwap: Invalid encrypted amounts"
        );

        positionCounter++;
        positionId = positionCounter;

        // Calculate liquidity tokens (simplified for demonstration)
        uint256 liquidityTokens = _calculateLiquidityTokens(_pairId, _encryptedAmountA, _encryptedAmountB);
        
        liquidityPositions[positionId] = LiquidityPosition({
            positionId: positionId,
            provider: msg.sender,
            pairId: _pairId,
            encryptedLiquidityA: _encryptedAmountA,
            encryptedLiquidityB: _encryptedAmountB,
            liquidityTokens: liquidityTokens,
            timestamp: block.timestamp,
            isActive: true
        });

        userPositions[msg.sender].push(positionId);

        // Update pair reserves using homomorphic addition
        pair.reserveA = confidentialMath.addToPublicSum(pair.reserveA, _encryptedAmountA);
        pair.reserveB = confidentialMath.addToPublicSum(pair.reserveB, _encryptedAmountB);
        pair.totalLiquidity += liquidityTokens;

        emit LiquidityAdded(positionId, msg.sender, _pairId, liquidityTokens);

        return positionId;
    }

    /**
     * @notice Place a secret order with encrypted amounts
     * @param _pairId Trading pair identifier
     * @param _encryptedAmountIn Encrypted input amount
     * @param _encryptedMinAmountOut Encrypted minimum output amount
     * @param _tokenIn Input token address
     * @param _tokenOut Output token address
     * @param _deadline Order expiration timestamp
     * @param _orderType Type of order (market/limit)
     * @param _proofData Proof of encrypted amounts validity
     * @return orderId Unique order identifier
     */
    function placeSecretOrder(
        bytes32 _pairId,
        bytes32 _encryptedAmountIn,
        bytes32 _encryptedMinAmountOut,
        address _tokenIn,
        address _tokenOut,
        uint256 _deadline,
        OrderType _orderType,
        bytes32 _proofData
    ) external payable nonReentrant whenNotPaused validPair(_pairId) returns (uint256 orderId) {
        require(_deadline > block.timestamp, "SecretSwap: Invalid deadline");
        require(_tokenIn != _tokenOut, "SecretSwap: Identical tokens");
        
        TradingPair memory pair = tradingPairs[_pairId];
        require(
            (_tokenIn == pair.tokenA && _tokenOut == pair.tokenB) ||
            (_tokenIn == pair.tokenB && _tokenOut == pair.tokenA),
            "SecretSwap: Invalid token pair"
        );

        // Verify encrypted amounts
        require(
            confidentialMath.isEncryptedDataValid(_encryptedAmountIn) &&
            confidentialMath.isEncryptedDataValid(_encryptedMinAmountOut),
            "SecretSwap: Invalid encrypted amounts"
        );

        orderCounter++;
        orderId = orderCounter;

        secretOrders[orderId] = SecretOrder({
            orderId: orderId,
            trader: msg.sender,
            pairId: _pairId,
            encryptedAmountIn: _encryptedAmountIn,
            encryptedMinAmountOut: _encryptedMinAmountOut,
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            deadline: _deadline,
            isExecuted: false,
            isCancelled: false,
            proofData: _proofData,
            orderType: _orderType,
            timestamp: block.timestamp
        });

        userOrders[msg.sender].push(orderId);
        pairOrders[_pairId].push(orderId);

        emit SecretOrderPlaced(orderId, msg.sender, _pairId, _encryptedAmountIn, block.timestamp);

        return orderId;
    }

    /**
     * @notice Execute a secret order (market orders can be auto-executed)
     * @param _orderId Order to execute
     * @param _encryptedAmountOut Encrypted output amount
     * @param _executionProof Proof of valid execution
     */
    function executeSecretOrder(
        uint256 _orderId,
        bytes32 _encryptedAmountOut,
        bytes32 _executionProof
    ) external nonReentrant whenNotPaused validOrder(_orderId) {
        SecretOrder storage order = secretOrders[_orderId];
        require(block.timestamp <= order.deadline, "SecretSwap: Order expired");
        require(
            msg.sender == order.trader || msg.sender == owner(),
            "SecretSwap: Not authorized to execute"
        );

        TradingPair storage pair = tradingPairs[order.pairId];
        
        // Verify execution is valid using confidential math
        require(
            _verifyExecution(order, _encryptedAmountOut, _executionProof),
            "SecretSwap: Invalid execution proof"
        );

        order.isExecuted = true;

        // Update reserves after execution
        if (order.tokenIn == pair.tokenA) {
            pair.reserveA = confidentialMath.addToPublicSum(pair.reserveA, order.encryptedAmountIn);
            pair.reserveB = _subtractFromReserve(pair.reserveB, _encryptedAmountOut);
        } else {
            pair.reserveB = confidentialMath.addToPublicSum(pair.reserveB, order.encryptedAmountIn);
            pair.reserveA = _subtractFromReserve(pair.reserveA, _encryptedAmountOut);
        }

        emit SecretOrderExecuted(_orderId, order.pairId, _encryptedAmountOut, block.timestamp);
    }

    /**
     * @notice Cancel a pending order
     * @param _orderId Order to cancel
     */
    function cancelSecretOrder(uint256 _orderId) 
        external 
        nonReentrant 
        validOrder(_orderId) 
        onlyOrderOwner(_orderId) 
    {
        SecretOrder storage order = secretOrders[_orderId];
        order.isCancelled = true;
    }

    /**
     * @notice Remove liquidity from a position
     * @param _positionId Liquidity position to remove
     * @param _liquidityAmount Amount of liquidity tokens to remove
     */
    function removeSecretLiquidity(
        uint256 _positionId,
        uint256 _liquidityAmount
    ) external nonReentrant whenNotPaused {
        require(_positionId > 0 && _positionId <= positionCounter, "SecretSwap: Invalid position");
        
        LiquidityPosition storage position = liquidityPositions[_positionId];
        require(position.provider == msg.sender, "SecretSwap: Not position owner");
        require(position.isActive, "SecretSwap: Position not active");
        require(_liquidityAmount <= position.liquidityTokens, "SecretSwap: Insufficient liquidity");

        TradingPair storage pair = tradingPairs[position.pairId];

        // Calculate proportional amounts to return
        uint256 sharePercentage = (_liquidityAmount * 10000) / position.liquidityTokens;
        
        // Update position
        position.liquidityTokens -= _liquidityAmount;
        if (position.liquidityTokens == 0) {
            position.isActive = false;
        }

        // Update pair liquidity
        pair.totalLiquidity -= _liquidityAmount;

        emit LiquidityRemoved(_positionId, msg.sender, position.pairId, _liquidityAmount);
    }

    // Internal functions
    function _calculateLiquidityTokens(
        bytes32 _pairId,
        bytes32 _encryptedAmountA,
        bytes32 _encryptedAmountB
    ) internal view returns (uint256) {
        TradingPair memory pair = tradingPairs[_pairId];
        
        if (pair.totalLiquidity == 0) {
            // First liquidity provider gets MIN_LIQUIDITY tokens
            return MIN_LIQUIDITY;
        } else {
            // Calculate proportional liquidity tokens
            // This is simplified - in production would use more sophisticated AMM math
            return (pair.totalLiquidity * 1000) / (pair.reserveA + pair.reserveB + 1000);
        }
    }

    function _verifyExecution(
        SecretOrder memory _order,
        bytes32 _encryptedAmountOut,
        bytes32 _executionProof
    ) internal view returns (bool) {
        // Verify the execution proof using confidential math
        return confidentialMath.verifyEncryptedAmount(
            _encryptedAmountOut,
            0, // Placeholder - would calculate expected amount
            _executionProof
        );
    }

    function _subtractFromReserve(uint256 _reserve, bytes32 _encryptedAmount) 
        internal 
        view 
        returns (uint256) 
    {
        // In production, this would use homomorphic subtraction
        // For simulation, we approximate the subtraction
        uint256 amountToSubtract = uint256(_encryptedAmount) % 1000; // Simplified
        return _reserve > amountToSubtract ? _reserve - amountToSubtract : 0;
    }

    // View functions
    function getTradingPair(bytes32 _pairId) external view returns (TradingPair memory) {
        return tradingPairs[_pairId];
    }

    function getSecretOrder(uint256 _orderId) external view returns (SecretOrder memory) {
        return secretOrders[_orderId];
    }

    function getLiquidityPosition(uint256 _positionId) 
        external 
        view 
        returns (LiquidityPosition memory) 
    {
        return liquidityPositions[_positionId];
    }

    function getUserOrders(address _user) external view returns (uint256[] memory) {
        return userOrders[_user];
    }

    function getUserPositions(address _user) external view returns (uint256[] memory) {
        return userPositions[_user];
    }

    function getPairOrders(bytes32 _pairId) external view returns (uint256[] memory) {
        return pairOrders[_pairId];
    }

    function getAllPairIds() external view returns (bytes32[] memory) {
        return allPairIds;
    }

    // Admin functions
    function pauseTrading() external onlyOwner {
        _pause();
    }

    function resumeTrading() external onlyOwner {
        _unpause();
    }

    function deactivatePair(bytes32 _pairId) external onlyOwner {
        tradingPairs[_pairId].isActive = false;
    }

    function emergencyWithdraw(address _token) external onlyOwner {
        if (_token == address(0)) {
            payable(owner()).transfer(address(this).balance);
        } else {
            IERC20(_token).safeTransfer(owner(), IERC20(_token).balanceOf(address(this)));
        }
    }
}