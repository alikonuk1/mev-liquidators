// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {InitLiquidator} from "src/Init/InitLiquidator.sol";

contract DeployScript is Script {
    InitLiquidator initLiquidator;

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        initLiquidator = new InitLiquidator();
        vm.stopBroadcast();
    }
}
