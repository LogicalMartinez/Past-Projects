// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "../lib/forge-std/src/Script.sol";
import {DarkPool} from "../src/DarkPool.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    int256 public constant USDC_USD_PRICE = 1e8;

    uint256 public ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig {
        address WBTCUsdPriceFeed;
        address USDCUsdPriceFeed;
        address USDC;
        address WBTC;
        uint256 deployerKey;
    }

    constructor() {
        // if (block.chainid == 11155111) {
        activeNetworkConfig = getSepoliaConfig();
        // } else {
        // activeNetworkConfig = getAnvilConfig();
        // }
    }

    function getSepoliaConfig()
        public
        view
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            WBTCUsdPriceFeed: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c, // BTC / USD
            USDCUsdPriceFeed: 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6,
            USDC: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            WBTC: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAnvilConfig()
        public
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        if (activeNetworkConfig.WBTCUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();

        MockV3Aggregator WBTCUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            BTC_USD_PRICE
        );
        ERC20Mock WBTCMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);

        MockV3Aggregator USDCUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            USDC_USD_PRICE
        );
        ERC20Mock USDCMock = new ERC20Mock("USDC", "USDC", msg.sender, 1000e8);

        vm.stopBroadcast();
        anvilNetworkConfig = NetworkConfig({
            WBTCUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43, // BTC / USD
            USDCUsdPriceFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E,
            USDC: 0x07865c6E87B9F70255377e024ace6630C1Eaa37F,
            WBTC: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: ANVIL_PRIVATE_KEY
        });
    }
}
