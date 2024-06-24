// SPDX-License-Identifier: None
pragma solidity ^0.8.19;

// @ mnt-eth = 3200, eth-usd = 2200
//    pair         |  col | bor |  B  |  Q  |   limit (sl)  |  limit (tp)  |
// ETH-USD (long)  |  ETH | USD | ETH | USD |    < 2000     |    > 3000    |
// ETH-USD (short) |  USD | ETH | ETH | USD |    > 3000     |    < 2000    |
// MNT-ETH (long)  |  MNT | ETH | ETH | MNT |    < 3000     |    > 4000    |
// MNT-ETH (short) |  ETH | MNT | ETH | MNT |    > 4000     |    > 3000    |

// enums
enum OrderType {
    StopLoss,
    TakeProfit
}

enum OrderStatus {
    Cancelled,
    Active,
    Filled
}

enum SwapType {
    OpenExactIn,
    CloseExactIn,
    CloseExactOut
}

// structs
struct Order {
    uint256 initPosId; // nft id
    uint256 triggerPrice_e36; // price (base asset price / quote asset price) to trigger limit order
    uint256 limitPrice_e36; // price limit price (base asset price / quote asset price) to fill order
    uint256 collAmt; // size of collateral to be used in order
    address tokenOut; // token to transfer to pos owner
    OrderType orderType; // stop loss or take profit
    OrderStatus status; // cancelled, active, filled
    address recipient; // address to receive tokenOut
}

struct MarginPos {
    address collPool; // lending pool to deposit holdToken
    address borrPool; // lending pool to borrow borrowToken
    address baseAsset; // base asset of position
    address quoteAsset; // quote asset of position
    bool isLongBaseAsset; // long base asset or not
}

struct SwapInfo {
    uint256 initPosId; // nft id
    SwapType swapType; // swap type
    address tokenIn; // token to swap
    address tokenOut; // token to receive from swap
    uint256 amtOut; // token amount out info for the swap
    bytes data; // swap data
}

interface IMarginTradingHook {
    // events
    event SwapToIncreasePos(
        uint256 indexed initPosId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amtIn,
        uint256 amtOut
    );
    event SwapToReducePos(
        uint256 indexed initPosId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amtIn,
        uint256 amtOut
    );

    event IncreasePos(
        uint256 indexed initPosId,
        address indexed tokenIn,
        address indexed borrToken,
        uint256 amtIn,
        uint256 borrowAmt
    );
    event ReducePos(
        uint256 indexed initPosId,
        address indexed tokenOut,
        uint256 amtOut,
        uint256 size,
        uint256 repayAmt
    );
    event CreateOrder(
        uint256 indexed initPosId,
        uint256 indexed orderId,
        address tokenOut,
        uint256 triggerPrice_e36,
        uint256 limitPrice_e36,
        uint256 size,
        OrderType orderType
    );

    event UpdateOrder(
        uint256 indexed initPosId,
        uint256 indexed orderId,
        address tokenOut,
        uint256 triggerPrice_e36,
        uint256 limitPrice_e36,
        uint256 size
    );
    event CancelOrder(uint256 indexed initPosId, uint256 indexed orderId);
    event FillOrder(
        uint256 indexed initPosId,
        uint256 indexed orderId,
        address tokenOut,
        uint256 amtOut
    );

    // struct
    struct IncreasePosInternalParam {
        uint256 initPosId; // nft id
        address tokenIn; // token to transfer from msg.sender
        uint256 amtIn; // token amount to transfer from msg sender (for wNative, amt to transfer will reduce by msg value)
        address borrPool; // lending pool to borrow
        uint256 borrAmt; // token amount to borrow
        address collPool; // lending pool to deposit
        bytes data; // swap data
        uint256 minHealth_e18; // minimum health to maintain after execute
    }

    struct ReducePosInternalParam {
        uint256 initPosId; // nft id
        uint256 collAmt; // collateral amt to reduce
        uint256 repayShares; // debt shares to repay
        address tokenOut; // token to transfer to msg sender
        uint256 minAmtOut; // minimum amount of token to transfer to msg sender
        bool returnNative; // return wNative as native token or not (using balanceOf(address(this)))
        bytes data; // swap data
        uint256 minHealth_e18; // minimum health to maintain after execute
    }

    // functions
    /// @dev open margin trading position
    /// @param _mode position mode to be used
    /// @param _viewer address to view position
    /// @param  _tokenIn token to transfer from msg.sender
    /// @param _amtIn token amount to transfer from msg sender (for wNative, amt to transfer will reduce by msg value)
    /// @param _borrPool lending pool to borrow
    /// @param _borrAmt token amount to borrow
    /// @param _collPool lending pool to deposit
    /// @param _data swap data
    /// @param _minHealth_e18 minimum health to maintain after execute
    /// @return posId margin trading position id
    ///         initPosId init position id (nft id)
    ///         health_e18 position health after execute
    function openPos(
        uint16 _mode,
        address _viewer,
        address _tokenIn,
        uint256 _amtIn,
        address _borrPool,
        uint256 _borrAmt,
        address _collPool,
        bytes calldata _data,
        uint256 _minHealth_e18
    ) external payable returns (uint256 posId, uint256 initPosId, uint256 health_e18);

    /// @dev increase position size (need to borrow)
    /// @param _posId margin trading position id
    /// @param  _tokenIn token to transfer from msg.sender
    /// @param _amtIn token amount to transfer from msg sender (for wNative, amt to transfer will reduce by msg value)
    /// @param _borrAmt token amount to borrow
    /// @param _data swap data
    /// @param _minHealth_e18 minimum health to maintain after execute
    /// @return health_e18 position health after execute
    function increasePos(
        uint256 _posId,
        address _tokenIn,
        uint256 _amtIn,
        uint256 _borrAmt,
        bytes calldata _data,
        uint256 _minHealth_e18
    ) external payable returns (uint256 health_e18);

    /// @dev add collarteral to position
    /// @param _posId position id
    /// @param _amtIn token amount to transfer from msg sender (for wNative, amt to transfer will reduce by msg value)
    /// @return health_e18 position health after execute
    function addCollateral(uint256 _posId, uint256 _amtIn)
        external
        payable
        returns (uint256 health_e18);

    /// @dev remove collateral from position
    /// @param _posId margin trading position id
    /// @param _shares shares amount to withdraw
    /// @param _returnNative return wNative as native token or not (using balanceOf(address(this)))
    function removeCollateral(uint256 _posId, uint256 _shares, bool _returnNative)
        external
        returns (uint256 health_e18);

    /// @dev repay debt of position
    /// @param _posId margin trading position id
    /// @param _repayShares debt shares to repay
    /// @return repayAmt actual amount of debt repaid
    ///         health_e18 position health after execute
    function repayDebt(uint256 _posId, uint256 _repayShares)
        external
        payable
        returns (uint256 repayAmt, uint256 health_e18);

    /// @dev reduce position size
    /// @param _posId margin trading position id
    /// @param _collAmt collateral amt to reduce
    /// @param _repayShares debt shares to repay
    /// @param _tokenOut token to transfer to msg sender
    /// @param _minAmtOut minimum amount of token to transfer to msg sender
    /// @param _returnNative return wNative as native token or not (using balanceOf(address(this)))
    /// @param _data swap data
    /// @param _minHealth_e18 minimum health to maintain after execute
    /// @return amtOut actual amount of token transferred to msg sender
    ///         health_e18 position health after execute
    function reducePos(
        uint256 _posId,
        uint256 _collAmt,
        uint256 _repayShares,
        address _tokenOut,
        uint256 _minAmtOut,
        bool _returnNative,
        bytes calldata _data,
        uint256 _minHealth_e18
    ) external returns (uint256 amtOut, uint256 health_e18);

    /// @dev create stop loss order
    /// @param _posId margin trading position id
    /// @param _triggerPrice_e36 oracle price (quote asset price / base asset price) to trigger limit order
    /// @param _tokenOut token to transfer to msg sender
    /// @param _limitPrice_e36 price limit price (quote asset price / base asset price) to fill order
    /// @param _collAmt collateral size for the order
    /// @return orderId order id
    function addStopLossOrder(
        uint256 _posId,
        uint256 _triggerPrice_e36,
        address _tokenOut,
        uint256 _limitPrice_e36,
        uint256 _collAmt
    ) external returns (uint256 orderId);

    /// @dev create take profit order
    /// @param _posId margin trading position id
    /// @param _triggerPrice_e36 oracle price (quote asset price / base asset price) to trigger limit order
    /// @param _tokenOut token to transfer to msg sender
    /// @param _limitPrice_e36 price limit price (quote asset price / base asset price) to fill order
    /// @param _collAmt share of collateral to use in order
    /// @return orderId order id
    function addTakeProfitOrder(
        uint256 _posId,
        uint256 _triggerPrice_e36,
        address _tokenOut,
        uint256 _limitPrice_e36,
        uint256 _collAmt
    ) external returns (uint256 orderId);

    /// @dev update order
    /// @param _orderId order id
    /// @param _triggerPrice_e36 oracle price (quote asset price / base asset price) to trigger limit order
    /// @param _tokenOut token to transfer to msg sender
    /// @param _limitPrice_e36 price limit price (quote asset price / base asset price) to fill order
    /// @param _collAmt share of collateral to use in order
    function updateOrder(
        uint256 _posId,
        uint256 _orderId,
        uint256 _triggerPrice_e36,
        address _tokenOut,
        uint256 _limitPrice_e36,
        uint256 _collAmt
    ) external;

    /// @dev cancel order
    /// @param _posId margin trading position id
    /// @param _orderId order id
    function cancelOrder(uint256 _posId, uint256 _orderId) external;

    /// @dev arbitrager reduce position in order and collateral at limit price
    /// @param _orderId order id
    function fillOrder(uint256 _orderId) external;

    /// @notice _tokenA and _tokenB MUST be different
    /// @dev set quote asset of pair
    /// @param _tokenA token A of pair
    /// @param _tokenB token B of pair
    /// @param _quoteAsset quote asset of pair
    function setQuoteAsset(address _tokenA, address _tokenB, address _quoteAsset)
        external;

    /// @dev get base asset and token asset of pair
    /// @param _tokenA token A of pair
    /// @param _tokenB token B of pair
    /// @return baseAsset base asset of pair
    /// @return quoteAsset quote asset of pair
    function getBaseAssetAndQuoteAsset(address _tokenA, address _tokenB)
        external
        view
        returns (address baseAsset, address quoteAsset);

    /// @dev get order information
    /// @param _orderId order id
    /// @return order order information
    function getOrder(uint256 _orderId) external view returns (Order memory);

    /// @dev get margin position information
    /// @param _initPosId init position id (nft id)
    /// @return marginPos margin position information
    function getMarginPos(uint256 _initPosId) external view returns (MarginPos memory);

    /// @dev get position's orders length
    /// @param _initPosId init position id (nft id)
    function getPosOrdersLength(uint256 _initPosId) external view returns (uint256);

    /// @dev get hook's order id
    function lastOrderId() external view returns (uint256);

    /// @dev get all position's order ids
    /// @param _initPosId init position id (nft id)
    function getPosOrderIds(uint256 _initPosId)
        external
        view
        returns (uint256[] memory);
}
