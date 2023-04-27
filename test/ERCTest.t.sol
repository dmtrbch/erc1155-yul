// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "./lib/YulDeployer.sol";
import "forge-std/console2.sol";

interface ERCTest {
    function myFunc() external view returns (uint256);

    function owner() external view returns (uint256);
}

contract ERCTestTest is Test {
    YulDeployer yulDeployer = new YulDeployer();

    ERCTest erc1155Contract;

    function setUp() public {
        erc1155Contract = ERCTest(yulDeployer.deployContract("ERCTest"));
    }

    function testERCTestmyFunc() public {
        uint256 res = erc1155Contract.myFunc();

        assertEq(res, 6);
    }

    function testERCTestowner() public {
        uint256 res = erc1155Contract.owner();
        console2.logUint(res);
        assertTrue(true);
    }
}