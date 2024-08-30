// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/uniswap/ISwapRouter.sol";
import "./interfaces/uniswap/IUniswapV3Pool.sol";
import "./interfaces/ISwapper.sol";

contract UniswapV3Swap is ISwapper {

    ISwapRouter public immutable router;

    constructor(address _router) {
        require(_router != address(0), "invalid router");

        router = ISwapRouter(_router);
    }

    /// @inheritdoc ISwapper
    function swapAmountIn(
        address _tokenIn,
        address _tokenOut,
        uint256 _amount,
        address _siloAsset
    ) external override returns (uint256 amountOut) {
        uint24 fee = resolveFee( _siloAsset);
        return _swapAmountIn(_tokenIn, _tokenOut, _amount, fee);
    }

    /// @inheritdoc ISwapper
    function swapAmountOut(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountOut,
        address _siloAsset
    ) external override returns (uint256 amountIn) {
        uint24 fee = resolveFee(_siloAsset);
        return _swapAmountOut(_tokenIn, _tokenOut, _amountOut, fee);
    }

    /// @inheritdoc ISwapper
    function spenderToApprove() external view override returns (address) {
        return address(router);
    }

    function resolveFee(address _asset)
        public
        view
        returns (uint24 fee)
    {
        address poolAddress;

        // RDNT
        if (_asset == 0x3082CC23568eA640225c2467653dB90e9250AaA0){
            poolAddress = 0x446BF9748B4eA044dd759d9B9311C70491dF8F29;
        // USDCe
        } else if (_asset == 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8){
            poolAddress = 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443;
        // rETH
        } else if (_asset == 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8){
            poolAddress = 0xAac7DE2b91293BA1791503d9127d2bDf2159db65;
        }

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        fee = pool.fee();
    }

    function pathToBytes(address[] memory path, uint24[] memory fees)
        public
        pure
        returns (bytes memory bytesPath)
    {
        for (uint256 i = 0; i < path.length; i++) {
            bytesPath = i == fees.length
                ? abi.encodePacked(bytesPath, path[i])
                : abi.encodePacked(bytesPath, path[i], fees[i]);
        }
    }

    function _swapAmountIn(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint24 _fee
    ) internal returns (uint256 amountOut) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: _fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: 1,
            sqrtPriceLimitX96: 0
        });

        return router.exactInputSingle(params);
    }

    function _swapAmountOut(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountOut,
        uint24 _fee
    ) internal returns (uint256 amountOut) {
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: _fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: _amountOut,
            amountInMaximum: type(uint256).max,
            sqrtPriceLimitX96: 0
        });

        return router.exactOutputSingle(params);
    }
}
