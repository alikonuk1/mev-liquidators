// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IInitCore} from "./interfaces/IInitCore.sol";
import {IPosManager} from "./interfaces/IPosManager.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {TokenFactors, IConfig} from "./interfaces/IConfig.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

contract InitLiquidator is Ownable {
    using Math for uint256;

    address private constant INIT_CORE = 0x972BcB0284cca0152527c4f70f8F689852bCAFc5; // Mantle
    uint256 private constant ONE_E18 = 1e18;

    address private immutable ORACLE;
    address private immutable POS_MANAGER;

    constructor() Ownable(msg.sender) {
        POS_MANAGER = IInitCore(INIT_CORE).POS_MANAGER();
        ORACLE = IInitCore(INIT_CORE).oracle();
    }

    function updateAndLiquidate(
        bytes calldata updateData,
        uint256 posId,
        address repayPool,
        address poolOut,
        uint256 minShare
    ) external payable onlyOwner {
        processCalls(updateData);
        uint256 repayShare = calculateRepayShare(posId);
        require(repayShare > 0, "Position still healthy!");

        IERC20(repayPool).approve(INIT_CORE, type(uint256).max);
        address underlying = ILendingPool(repayPool).underlyingToken();

        IERC20(underlying).approve(INIT_CORE, type(uint256).max);

        IInitCore(INIT_CORE).liquidate(posId, repayPool, repayShare, poolOut, minShare);
    }

    function processCalls(bytes calldata data) public payable {
        (address[] memory targets, bytes[] memory callData, uint256[] memory values) =
            abi.decode(data, (address[], bytes[], uint256[]));

        for (uint256 i = 0; i < targets.length; i++) {
            (bool success,) = targets[i].call{value: values[i]}(callData[i]);
            require(success, "External call failed!");
        }
    }

    function calculateRepayShare(uint256 posId) public returns (uint256) {
        (address[] memory collPools,,,,) = IPosManager(POS_MANAGER).getPosCollInfo(posId);
        (address[] memory debtPools, uint256[] memory debtShares) =
            IPosManager(POS_MANAGER).getPosBorrInfo(posId);
        require(collPools.length > 0, "No collateral pools found");
        require(debtPools.length > 0, "No debt pools found");

        uint256 debtShare = debtShares[0];

        uint256 healthFactor = IInitCore(INIT_CORE).getPosHealthCurrent_e18(posId);
        require(healthFactor > 0, "Skip zero health factor.");

        uint16 mode = IPosManager(POS_MANAGER).getPosMode(posId);
        address config = IInitCore(INIT_CORE).config();
        uint256 maxHealthAfterLiquidation_e18 =
            IConfig(config).getMaxHealthAfterLiq_e18(mode);

        uint256 scaledHealth = maxHealthAfterLiquidation_e18 - healthFactor;
        require(scaledHealth > 0, "Skip zero scaled health.");
        uint256 scaledSharesToRepay = (debtShare * scaledHealth) / 305000000000000000;
        return scaledSharesToRepay;
    }

    function calculateLiquidationPrice(uint256 posId, bool isCollateral)
        public
        returns (uint256)
    {
        uint256 totalBorrowCredit = IInitCore(INIT_CORE).getBorrowCreditCurrent_e36(posId);
        uint256 totalCollateralCredit =
            IInitCore(INIT_CORE).getCollateralCreditCurrent_e36(posId);

        (address[] memory collPools, uint256[] memory collAmts,,,) =
            IPosManager(POS_MANAGER).getPosCollInfo(posId);
        (address[] memory debtPools, uint256[] memory debtShares) =
            IPosManager(POS_MANAGER).getPosBorrInfo(posId);
        require(collPools.length > 0, "No collateral pools found");
        require(debtPools.length > 0, "No debt pools found");

        uint256 collateralAmt = collAmts[0];
        uint256 debtAmt = ILendingPool(debtPools[0]).debtShareToAmtCurrent(debtShares[0]);
        require(debtAmt > 0, "debtAmt is zero");
        uint16 mode = IPosManager(POS_MANAGER).getPosMode(posId);
        TokenFactors memory collFactor =
            IConfig(IInitCore(INIT_CORE).config()).getTokenFactors(mode, collPools[0]);
        TokenFactors memory borrFactor =
            IConfig(IInitCore(INIT_CORE).config()).getTokenFactors(mode, debtPools[0]);
        require(totalBorrowCredit > 0, "totalBorrowCredit is zero");
        require(collateralAmt > 0, "collateralAmt is zero");
        require(collFactor.collFactor_e18 > 0, "collFactor_e18 is zero");
        if (isCollateral) {
            uint256 denominator = collateralAmt * collFactor.collFactor_e18;

            uint256 liquidationPrice = totalBorrowCredit.mulDiv(ONE_E18, denominator);
            return liquidationPrice;
        } else {
            uint256 denominator = debtAmt * borrFactor.borrFactor_e18;

            uint256 liquidationPrice = totalCollateralCredit.mulDiv(ONE_E18, denominator);
            return liquidationPrice;
        }
    }

    function burnWithdraw(address lendingPool, uint256 sharesToBurn, address receiver)
        external
        returns (uint256 amount)
    {
        // 1. Transfer inTokens to the lending pool
        IERC20(lendingPool).transferFrom(msg.sender, lendingPool, sharesToBurn);

        // 2. Call burnTo to actually burn the tokens and handle any internal accounting or logic
        amount = IInitCore(INIT_CORE).burnTo(lendingPool, receiver);

        return amount;
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool sent,) = address(msg.sender).call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function withdrawERC20(address token, uint256 amount) external onlyOwner {
        require(
            IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance"
        );
        IERC20(token).transfer(msg.sender, amount);
    }

    receive() external payable {}
}
