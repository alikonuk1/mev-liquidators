// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "lib/forge-std/src/Test.sol";
import {DeployScript} from "script/DeployInit.s.sol";
import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {IInitCore} from "src/Init/interfaces/IInitCore.sol";
import {ILendingPool} from "src/Init/interfaces/ILendingPool.sol";
import {IPosManager} from "src/Init/interfaces/IPosManager.sol";
import {IInitOracle} from "src/Init/interfaces/IInitOracle.sol";

contract testTest is Test, DeployScript {
    address public INIT_CORE = 0x972BcB0284cca0152527c4f70f8F689852bCAFc5;
    address public POS_MANAGER = 0x0e7401707CD08c03CDb53DAEF3295DDFb68BBa92;
    address public INIT_ORACLE = 0x4E195A32b2f6eBa9c4565bA49bef34F23c2C0350;

    address public WETH = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
    address public WMNT = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;

    address public inWETH = 0x51AB74f8B03F0305d8dcE936B473AB587911AEC4;
    address public inWMNT = 0x44949636f778fAD2b139E665aee11a2dc84A2976;
    address public router = 0xeaEE7EE68874218c3558b40063c42B82D3E7232a;

    address public deployer = vm.addr(deployerPrivateKey);
    address public alice;
    address public bob;
    address public carol;
    address public zeroAddr;

    uint256 public mantleFork;

    address public BVM_ETH = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
    address public underlying_inWMNT = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;

    function setUp() public {
        mantleFork = vm.createSelectFork(vm.rpcUrl("mantle"));
        vm.rollFork(64_046_026);

        alice = makeAddr("Alice");
        bob = makeAddr("Bob");
        carol = makeAddr("Carol");
        zeroAddr = address(0);

        deal(alice, 999 ether);
        deal(bob, 999 ether);
        deal(carol, 999 ether);
        deal(WETH, deployer, 100 ether);
        deal(WMNT, deployer, 100 ether);

        DeployScript.run();

        deal(WETH, address(initLiquidator), 10000000000 ether);
        deal(WMNT, address(initLiquidator), 10000000000 ether);
    }

    function test_simulateLiquidate() public {
        uint256 posId =
            67023274737983072427381287414060723887646681971416343951624988593736628812676;

        uint256 hFB = IInitCore(INIT_CORE).getPosHealthCurrent_e18(posId);
        console2.log("Health Factor Before =", hFB);

        (address[] memory collPools,,,,) = IPosManager(POS_MANAGER).getPosCollInfo(posId);

        address undelying = ILendingPool(collPools[0]).underlyingToken();

        uint256 priceB = IInitOracle(INIT_ORACLE).getPrice_e36(undelying);
        console2.log("Collateral Price Before =", priceB);

        vm.mockCall(
            INIT_ORACLE,
            abi.encodeWithSelector(
                IInitOracle(INIT_ORACLE).getPrice_e36.selector, undelying
            ),
            abi.encode(100000000)
        );

        uint256 priceA = IInitOracle(INIT_ORACLE).getPrice_e36(undelying);
        console2.log("Collateral Price After =", priceA);

        uint256 hFA = IInitCore(INIT_CORE).getPosHealthCurrent_e18(posId);
        console2.log("Health Factor After =", hFA);

        vm.startPrank(deployer);
        //IERC20(WMNT).approve(INIT_CORE, type(uint256).max);
        initLiquidator.liquidate(posId, inWMNT, inWETH, 0);
        vm.stopPrank();

        uint256 hFf = IInitCore(INIT_CORE).getPosHealthCurrent_e18(posId);
        console2.log("Health Factor Final =", hFf);
    }
}
