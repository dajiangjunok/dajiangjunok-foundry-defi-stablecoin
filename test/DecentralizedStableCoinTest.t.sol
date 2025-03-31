// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DeployDecentralizedStableCoin} from "../script/DeployDecentralizedStableCoin.s.sol";

contract DecentralizedStableCoinTest is Test {
    // 金额必须大于0错误
    error DecentralizedStableCoin__MustBeMoreThanZero();
    // 销毁金额超过余额错误
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    // 地址不能为0地址错误
    error DecentralizedStableCoin__NotZeroAddress();
    // 未授权账户错误
    error OwnableUnauthorizedAccount(address account);

    DecentralizedStableCoin decentralizedStableCoin; // 合约实例
    address public immutable USER = makeAddr("user");
    address public owner;

    function setUp() public {
        DeployDecentralizedStableCoin deployer = new DeployDecentralizedStableCoin();
        decentralizedStableCoin = deployer.run();
        owner = decentralizedStableCoin.owner();
    }

    function testNameIsCorrect() public view {
        // Arrange
        string memory expectedName = "DecentralizedStableCoin";
        string memory expectedSymbol = "DSC";
        // Act
        string memory name = decentralizedStableCoin.name();
        string memory systemName = decentralizedStableCoin.symbol();
        // Assert
        assertEq(name, expectedName);
        assertEq(systemName, expectedSymbol);
        // assert(
        //     keccak256(abi.encodePacked(name)) ==
        //         keccak256(abi.encodePacked(expectedName))
        // );
        // assert(
        //     keccak256(abi.encodePacked(systemName)) ==
        //         keccak256(abi.encodePacked(systemName))
        // );
    }

    ////////////////////////////
    //      铸造测试           //
    ///////////////////////////

    // 铸造失败，没有权限
    function testMintHasNotAccess() public {
        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, USER)
        );
        decentralizedStableCoin.mint(USER, 100);
    }

    // 地址为0
    function testMintZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin__NotZeroAddress.selector);
        decentralizedStableCoin.mint(address(0), 100);
    }

    // 铸造数量为0
    function testMintZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin__MustBeMoreThanZero.selector);
        decentralizedStableCoin.mint(owner, 0);
    }

    ////////////////////////////
    //      销毁测试           //
    ///////////////////////////

    // 非所有者调用burn方法应该失败
    function testBurnHasNotAccess() public {
        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, USER)
        );
        decentralizedStableCoin.burn(100);
    }

    // 销毁金额为0应该失败
    function testBurnZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin__MustBeMoreThanZero.selector);
        decentralizedStableCoin.burn(0);
    }

    // 销毁金额超过余额应该失败
    function testBurnAmountExceedsBalance() public {
        vm.prank(owner);
        vm.expectRevert(
            DecentralizedStableCoin__BurnAmountExceedsBalance.selector
        );
        decentralizedStableCoin.burn(100);
    }

    // 正常销毁场景应该成功
    function testBurnSuccess() public {
        // 先给owner铸造一些代币
        vm.prank(owner);
        decentralizedStableCoin.mint(owner, 100);

        // 执行销毁
        vm.prank(owner);
        decentralizedStableCoin.burn(50);

        // 验证余额
        assertEq(decentralizedStableCoin.balanceOf(owner), 50);
    }
}
