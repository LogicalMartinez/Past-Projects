// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {A0FinancialGroup} from "../src/A0FinancialGroup.sol";

contract DeployA0FinancialGroup is Script {
    uint256 public deployerKey;
    string private TokenUri =
        "ipfs://bafkreifnzvbgezdniasdlwjgpg3i7kkfgts43iglm7veahio2ghc7cqlge";

    function run() external returns (A0FinancialGroup) {
        deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast();
        A0FinancialGroup A0Financial = new A0FinancialGroup(TokenUri);
        vm.stopBroadcast();
        return A0Financial;
    }
}
