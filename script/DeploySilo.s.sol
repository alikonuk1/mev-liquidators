// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {SiloLiquidator} from "src/Silo/SiloLiquidator.sol";
import {UniswapV3Swap} from "src/Silo/UniswapV3Swap.sol";
import {IPriceProvider} from "src/Silo/interfaces/IPriceProvider.sol";
import {ISwapper} from "src/Silo/interfaces/ISwapper.sol";

contract DeployScript is Script {
    SiloLiquidator siloLiquidator;
    UniswapV3Swap uniswapV3Swap;

    address public SILO_REPOSITORY = 0x8658047e48CC09161f4152c79155Dac1d710Ff0a;
    address public SILO_LENS = 0xBDb843c7a7e48Dc543424474d7Aa63b61B5D9536;
    address public PRICE_PROVIDER = 0x9d0DDE842801448534263FF23C629EDC6B6B31ee;
    address public SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public {

        vm.startBroadcast(deployerPrivateKey);
        uniswapV3Swap = new UniswapV3Swap(SWAP_ROUTER);

        IPriceProvider[] memory priceProviders = new IPriceProvider[](1);
        priceProviders[0] = IPriceProvider(PRICE_PROVIDER);

        ISwapper[] memory swappers = new ISwapper[](1);
        swappers[0] = uniswapV3Swap;

        siloLiquidator =
            new SiloLiquidator(SILO_REPOSITORY, priceProviders, swappers);
        vm.stopBroadcast();
    }
}
