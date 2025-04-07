// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    address public USER = makeAddr("user");

    function setUp() public {
        DeployDecentralizedStableCoin deployer = new DeployDecentralizedStableCoin();
        (dsc, dscEngine, ) = deployer.run();
    }

    // 修改测试用例，通过 DSCEngine 来操作 DSC
    function testMintSuccessfully() public {
        vm.startPrank(address(dscEngine));
        dsc.mint(USER, 100);
        assertEq(dsc.balanceOf(USER), 100);
        vm.stopPrank();
    }

    function testBurnSuccessfully() public {
        // 先铸造一些代币给 USER
        vm.startPrank(address(dscEngine));
        dsc.mint(USER, 100);
        vm.stopPrank();

        // USER 先授权给 dscEngine
        vm.prank(USER);
        dsc.approve(address(dscEngine), 100);

        // 然后通过 dscEngine 销毁 USER 的代币
        vm.prank(address(dscEngine));
        dsc.burnFrom(USER, 50); // 使用 burnFrom 而不是 burn
        assertEq(dsc.balanceOf(USER), 50);
    }
}
