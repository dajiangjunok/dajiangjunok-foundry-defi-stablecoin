// Hove our invariant aka properties
// What are our invariants?
// 1.DSC 总供应量应该小于质押品的总价值
// 2. getter view function should never revert <- evergreen invariant
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelpConfig.s.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployDecentralizedStableCoin deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address wethToken;
    address wbtcToken;

    function setUp() external {
        deployer = new DeployDecentralizedStableCoin();
        (dsc, dscEngine, config) = deployer.run();
        (, , address weth, address wbtc, ) = config.activeNetworkConfig();
        wethToken = weth;
        wbtcToken = wbtc;

        Handler handler = new Handler(dscEngine, dsc);

        targetContract(address(handler));

        // 除非有抵押品要赎回，否责不要调用赎回抵押品
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // 获取所有质押品的价值
        // 获取DSC的总供应量
        uint256 totalSupply = dsc.totalSupply();
        // 获取存入DSCEngine合约的WETH总量
        uint256 totalWethDeposited = IERC20(wethToken).balanceOf(
            address(dscEngine)
        );
        // 获取存入DSCEngine合约的WBTC总量
        uint256 totalWbtcDeposited = IERC20(wbtcToken).balanceOf(
            address(dscEngine)
        );

        // 计算WETH的美元价值
        uint256 wethValue = dscEngine.getUsdValue(
            wethToken,
            totalWethDeposited
        );
        // 计算WBTC的美元价值
        uint256 wbtcValue = dscEngine.getUsdValue(
            wbtcToken,
            totalWbtcDeposited
        );
        // 打印各个值用于调试
        console.log("wethValue: ", wethValue);
        console.log("wbtcValue: ", wbtcValue);
        console.log("totalSupply: ", totalSupply);

        // 断言：质押品总价值必须大于等于DSC的总供应量
        assert(wethValue + wbtcValue >= totalSupply);
    }
}
