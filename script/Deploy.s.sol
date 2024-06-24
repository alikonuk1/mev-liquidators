// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {InitLiquidator} from "src/Init/InitLiquidator.sol";

contract DeployScript is Script {
    InitLiquidator initLiquidator;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        initLiquidator = new InitLiquidator();
        vm.stopBroadcast();
    }
}
