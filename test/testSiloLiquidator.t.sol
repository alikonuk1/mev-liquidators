// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "lib/forge-std/src/Test.sol";
import {DeployScript} from "script/DeploySilo.s.sol";
import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {ISilo} from "./../src/Silo/interfaces/ISilo.sol";
import {ISiloRepository} from "src/Silo/interfaces/ISiloRepository.sol";
import {IPriceProvidersRepository} from
    "src/Silo/interfaces/IPriceProvidersRepository.sol";

contract testTest is Test, DeployScript {
    address public PRICE_PROVIDERS_REPOSITORY = 0x5bf4E67127263D951FC515E23B323d0e3b4485fd;

    address public WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public rETH = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8;
    address public USDCe = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public RDNT = 0x3082CC23568eA640225c2467653dB90e9250AaA0;

    address public deployer = vm.addr(deployerPrivateKey);
    address public alice;
    address public bob;
    address public carol;
    address public zeroAddr;

    uint256 public arbitrumFork;

    ISiloRepository siloRepository = ISiloRepository(SILO_REPOSITORY);
    IPriceProvidersRepository priceProviderRepository =
        IPriceProvidersRepository(PRICE_PROVIDERS_REPOSITORY);

    function setUp() public {
        arbitrumFork = vm.createSelectFork(vm.rpcUrl("arbitrum"));
        //vm.rollFork(64_046_026);

        alice = makeAddr("Alice");
        bob = makeAddr("Bob");
        carol = makeAddr("Carol");
        zeroAddr = address(0);

        deal(alice, 999 ether);
        deal(bob, 999 ether);
        deal(carol, 999 ether);

        deal(rETH, alice, 100 ether);

        DeployScript.run();
    }

    function test_simulateLiquidate() public {
        address quoteToken = priceProviderRepository.quoteToken();

        // Alice deposits
        vm.startPrank(alice);
        ISilo silo = ISilo(siloRepository.getSilo(rETH));
        IERC20(rETH).approve(address(silo), 1 ether);
        silo.deposit(rETH, 1 ether, false);
        vm.stopPrank();

        // Alice borrows
        vm.startPrank(alice);
        silo.borrow(USDCe, 100000000); // Borrow 100 USDCe
        vm.stopPrank();

        // Check if Alice is solvent before price drop
        bool isSolventB = silo.isSolvent(alice);
        console2.log("Is Solvent Before =", isSolventB);
        assertEq(isSolventB, true);

        // Get collateral price before price drop
        uint256 priceB = priceProviderRepository.getPrice(rETH);
        console2.log("Collateral Price Before =", priceB);

        // Simulate price drop on collateral
        vm.mockCall(
            PRICE_PROVIDERS_REPOSITORY,
            abi.encodeWithSelector(priceProviderRepository.getPrice.selector, rETH),
            abi.encode(11674738096228163)
        );

        // Get collateral price after price drop
        uint256 priceA = priceProviderRepository.getPrice(rETH);
        console2.log("Collateral Price After =", priceA);
        assertEq(priceA, 11674738096228163);

        // Check if Alice is solvent after price drop
        bool isSolventA = silo.isSolvent(alice);
        console2.log("Is Solvent After =", isSolventA);
        assertEq(isSolventA, false);

        // Check liquidator balance before liquidation
        uint256 balanceB = IERC20(quoteToken).balanceOf(address(siloLiquidator));
        console2.log("Balance Before Liquidation =", balanceB);

        // Liquidate
        vm.startPrank(deployer);
        address[] memory users = new address[](1);
        users[0] = alice;
        siloLiquidator.executeLiquidation(users, silo);
        vm.stopPrank();

        // Check liquidator balance after liquidation
        uint256 balanceA = IERC20(quoteToken).balanceOf(address(siloLiquidator));
        console2.log("Balance After Liquidation =", balanceA);

        // Check if Alice is solvent after liquidation
        bool isSolventAL = silo.isSolvent(alice);
        console2.log("Is Solvent After Liquidation =", isSolventAL);
        assertEq(isSolventAL, true);
    }

    function test_withdrawEarnings() public {
        address quoteToken = priceProviderRepository.quoteToken();

        // Alice deposits
        vm.startPrank(alice);
        ISilo silo = ISilo(siloRepository.getSilo(rETH));
        IERC20(rETH).approve(address(silo), 1 ether);
        silo.deposit(rETH, 1 ether, false);
        vm.stopPrank();

        // Alice borrows
        vm.startPrank(alice);
        silo.borrow(USDCe, 100000000); // Borrow 100 USDCe
        vm.stopPrank();

        // Check if Alice is solvent before price drop
        bool isSolventB = silo.isSolvent(alice);
        console2.log("Is Solvent Before =", isSolventB);
        assertEq(isSolventB, true);

        // Get collateral price before price drop
        uint256 priceB = priceProviderRepository.getPrice(rETH);
        console2.log("Collateral Price Before =", priceB);

        // Simulate price drop on collateral
        vm.mockCall(
            PRICE_PROVIDERS_REPOSITORY,
            abi.encodeWithSelector(priceProviderRepository.getPrice.selector, rETH),
            abi.encode(11674738096228163)
        );

        // Get collateral price after price drop
        uint256 priceA = priceProviderRepository.getPrice(rETH);
        console2.log("Collateral Price After =", priceA);
        assertEq(priceA, 11674738096228163);

        // Check if Alice is solvent after price drop
        bool isSolventA = silo.isSolvent(alice);
        console2.log("Is Solvent After =", isSolventA);
        assertEq(isSolventA, false);

        // Check liquidator balance before liquidation
        uint256 balanceB = IERC20(quoteToken).balanceOf(address(siloLiquidator));
        console2.log("Liquidator Balance Before Liquidation =", balanceB);

        // Liquidate
        vm.startPrank(deployer);
        address[] memory users = new address[](1);
        users[0] = alice;
        siloLiquidator.executeLiquidation(users, silo);
        vm.stopPrank();

        // Check liquidator balance after liquidation
        uint256 balanceA = IERC20(quoteToken).balanceOf(address(siloLiquidator));
        console2.log("Liquidator Balance After Liquidation =", balanceA);

        // Check if Alice is solvent after liquidation
        bool isSolventAL = silo.isSolvent(alice);
        console2.log("Is Solvent After Liquidation =", isSolventAL);
        assertEq(isSolventAL, true);

        // Check liquidator deployers balance before withdraw
        uint256 balanceDB = IERC20(quoteToken).balanceOf(deployer);
        console2.log("Deployer Balance Before Withdraw =", balanceDB);

        // Liquidator deployer withdraws earnings
        vm.startPrank(deployer);
        siloLiquidator.withdraw();
        vm.stopPrank();

        // Check liquidator deployers balance after withdraw
        uint256 balanceDA = IERC20(quoteToken).balanceOf(deployer);
        console2.log("Deployer Balance After Withdraw =", balanceDA);
        assertEq(balanceDA, balanceA);
    }

    function test_withdrawEarningsInETH() public {
        address quoteToken = priceProviderRepository.quoteToken();

        // Alice deposits
        vm.startPrank(alice);
        ISilo silo = ISilo(siloRepository.getSilo(rETH));
        IERC20(rETH).approve(address(silo), 1 ether);
        silo.deposit(rETH, 1 ether, false);
        vm.stopPrank();

        // Alice borrows
        vm.startPrank(alice);
        silo.borrow(USDCe, 100000000); // Borrow 100 USDCe
        vm.stopPrank();

        // Check if Alice is solvent before price drop
        bool isSolventB = silo.isSolvent(alice);
        console2.log("Is Solvent Before =", isSolventB);
        assertEq(isSolventB, true);

        // Get collateral price before price drop
        uint256 priceB = priceProviderRepository.getPrice(rETH);
        console2.log("Collateral Price Before =", priceB);

        // Simulate price drop on collateral
        vm.mockCall(
            PRICE_PROVIDERS_REPOSITORY,
            abi.encodeWithSelector(priceProviderRepository.getPrice.selector, rETH),
            abi.encode(11674738096228163)
        );

        // Get collateral price after price drop
        uint256 priceA = priceProviderRepository.getPrice(rETH);
        console2.log("Collateral Price After =", priceA);
        assertEq(priceA, 11674738096228163);

        // Check if Alice is solvent after price drop
        bool isSolventA = silo.isSolvent(alice);
        console2.log("Is Solvent After =", isSolventA);
        assertEq(isSolventA, false);

        // Check liquidator balance before liquidation
        uint256 balanceB = IERC20(quoteToken).balanceOf(address(siloLiquidator));
        console2.log("Liquidator Balance Before Liquidation =", balanceB);

        // Liquidate
        vm.startPrank(deployer);
        address[] memory users = new address[](1);
        users[0] = alice;
        siloLiquidator.executeLiquidation(users, silo);
        vm.stopPrank();

        // Check liquidator balance after liquidation
        uint256 balanceA = IERC20(quoteToken).balanceOf(address(siloLiquidator));
        console2.log("Liquidator Balance After Liquidation =", balanceA);

        // Check if Alice is solvent after liquidation
        bool isSolventAL = silo.isSolvent(alice);
        console2.log("Is Solvent After Liquidation =", isSolventAL);
        assertEq(isSolventAL, true);

        // Check liquidator deployers balance before withdraw
        uint256 balanceDB = IERC20(quoteToken).balanceOf(deployer);
        console2.log("Deployer Balance Before Withdraw =", balanceDB);

        // Check liquidator deployers ETH balance before withdraw,
        uint256 balanceDBE = address(deployer).balance;
        console2.log("Deployer ETH Balance Before Withdraw =", balanceDBE);

        // Liquidator deployer withdraws earnings
        vm.startPrank(deployer);
        siloLiquidator.withdrawEth();
        vm.stopPrank();

        // Check liquidator deployers balance after withdraw
        uint256 balanceDA = IERC20(quoteToken).balanceOf(deployer);
        console2.log("Deployer Balance After Withdraw =", balanceDA);

        // Check liquidator deployers ETH balance after withdraw,
        uint256 balanceDAE = address(deployer).balance;
        console2.log("Deployer ETH Balance After Withdraw =", balanceDAE);
    }
}
