// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;

    function setUp() public {
        weth = new ERC20Mock();
        weth.mint(msg.sender, STARTING_ERC20_BALANCE);

        wbtc = new ERC20Mock();
        wbtc.mint(msg.sender, STARTING_ERC20_BALANCE);

        ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);

        dsc = new DecentralizedStableCoin();
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(weth);
        tokenAddresses[1] = address(wbtc);

        address[] memory priceFeedAddresses = new address[](2);
        priceFeedAddresses[0] = address(ethUsdPriceFeed);
        priceFeedAddresses[1] = address(btcUsdPriceFeed);

        dscEngine = new DSCEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(dsc)
        );

        dsc.transferOwnership(address(dscEngine));
    }

    function testDepositCollateralAndGetAccountInfo() public {
        vm.startPrank(USER);
        weth.mint(USER, AMOUNT_COLLATERAL);
        weth.approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL, USER);
        vm.stopPrank();

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine
            .getAccountInformation(USER);
        uint256 expectedDepositedAmount = (AMOUNT_COLLATERAL *
            uint256(ETH_USD_PRICE)) / 1e8;
        assertEq(totalDscMinted, 0);
        assertEq(collateralValueInUsd, expectedDepositedAmount);
    }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        weth.mint(USER, AMOUNT_COLLATERAL);
        weth.approve(address(dscEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.depositCollateral(address(weth), 0, USER);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randomToken = new ERC20Mock();
        randomToken.mint(USER, STARTING_ERC20_BALANCE);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(
            address(randomToken),
            AMOUNT_COLLATERAL,
            USER
        );
        vm.stopPrank();
    }
}
