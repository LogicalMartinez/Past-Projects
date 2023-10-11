// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Test.sol";
import {DarkPool} from "../src/DarkPool.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployDarkPool is Script {
    address[] public whitelist;
    address[] public priceFeeds;

    uint256 public ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external returns (DarkPool, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address WBTCUsdPriceFeed,
            address USDCUsdPriceFeed,
            address USDC,
            address WBTC,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        whitelist = [USDC, WBTC];
        priceFeeds = [USDCUsdPriceFeed, WBTCUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        DarkPool darkPool = new DarkPool(whitelist, priceFeeds);
        vm.stopBroadcast();
        return (darkPool, helperConfig);
    }
}
