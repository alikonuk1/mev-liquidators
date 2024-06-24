// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IInitFlashLiq {
    function flashLiquidate(
        uint256 _posId,
        address _poolToRepay,
        address _poolToSeize,
        address _router,
        bytes calldata swapData,
        uint256 _minAmtOut
    ) external returns (uint256 amtOut);

    function coreCallback(address sender, bytes calldata _data)
        external
        payable
        returns (bytes memory);
}
