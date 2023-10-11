// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployA0FinancialGroup} from "../script/DeployA0FinancialGroup.s.sol";
import {A0FinancialGroup} from "../src/A0FinancialGroup.sol";

contract A0MastermindNFTtest is Test {
    A0FinancialGroup public A0FinancialNFT;
    DeployA0FinancialGroup public deployer;
    string public constant s_A0Financial =
        "ipfs://bafkreifnzvbgezdniasdlwjgpg3i7kkfgts43iglm7veahio2ghc7cqlge";

    function setUp() external {
        deployer = new DeployA0FinancialGroup();
        (A0FinancialNFT) = deployer.run();
    }

    function testIfnftNamesAreEqual() external view {
        string memory expectedPassNumber = "A0 Financial";
        string memory realPassNumber = A0FinancialNFT.name();

        assert(
            keccak256(abi.encodePacked(expectedPassNumber)) ==
                keccak256(abi.encodePacked(realPassNumber))
        );
    }

    function testMintNFT() external {
        address alice = address(1);

        vm.prank(alice);
        A0FinancialNFT.mintNft();
    }
}
