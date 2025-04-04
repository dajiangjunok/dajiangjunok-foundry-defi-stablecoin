// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin public dsc;
    address public owner;
    address public user = makeAddr("user");

    function setUp() public {
        owner = msg.sender;
        dsc = new DecentralizedStableCoin();
    }

    function testMintSuccessfully() public {
        uint256 amount = 100 ether;
        vm.prank(owner);
        bool success = dsc.mint(user, amount);
        assertTrue(success);
        assertEq(dsc.balanceOf(user), amount);
    }

    function testMintFailsIfNotOwner() public {
        uint256 amount = 100 ether;
        vm.prank(user);
        vm.expectRevert();
        dsc.mint(user, amount);
    }

    function testMintFailsIfAmountZero() public {
        vm.startPrank(owner);
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__MustBeMoreThanZero
                .selector
        );
        dsc.mint(user, 0);
        vm.stopPrank();
    }

    function testMintFailsIfZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__NotZeroAddress
                .selector
        );
        dsc.mint(address(0), 100 ether);
        vm.stopPrank();
    }

    function testBurnSuccessfully() public {
        uint256 amount = 100 ether;
        vm.startPrank(owner);
        dsc.mint(owner, amount);
        dsc.burn(amount);
        vm.stopPrank();
        assertEq(dsc.balanceOf(owner), 0);
    }

    function testBurnFailsIfNotOwner() public {
        uint256 amount = 100 ether;
        vm.prank(owner);
        dsc.mint(user, amount);

        vm.prank(user);
        vm.expectRevert();
        dsc.burn(amount);
    }

    function testBurnFailsIfAmountZero() public {
        vm.startPrank(owner);
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__MustBeMoreThanZero
                .selector
        );
        dsc.burn(0);
        vm.stopPrank();
    }

    function testBurnFailsIfAmountExceedsBalance() public {
        uint256 mintAmount = 100 ether;
        uint256 burnAmount = 200 ether;
        vm.startPrank(owner);
        dsc.mint(owner, mintAmount);
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__BurnAmountExceedsBalance
                .selector
        );
        dsc.burn(burnAmount);
        vm.stopPrank();
    }
}
