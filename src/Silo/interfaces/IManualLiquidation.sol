// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IManualLiquidation {
    // Errors
    error InvalidSiloRepository();
    error NotSilo();
    error RepayFailed();
    error UsersMustMatchSilos();

    // Events
    event LiquidationExecuted(address indexed silo, address indexed user);

    // Functions
    function SILO_REPOSITORY() external view returns (address);

    function executeLiquidation(address _user, address _silo) external;

    function siloLiquidationCallback(
        address _user,
        address[] calldata _assets,
        uint256[] calldata _receivedCollaterals,
        uint256[] calldata _shareAmountsToRepaid,
        bytes calldata _flashReceiverData
    ) external;

    receive() external payable;
}
