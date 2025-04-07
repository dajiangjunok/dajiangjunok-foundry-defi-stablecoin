// SPDX-License-Identifier: MIT
// Handler is going to narrow down the way we call the function

pragma solidity ^0.8.26;
import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Handler} from "./Handler.t.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    ERC20Mock wbtc;
    ERC20Mock weth;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;
        address[] memory collateralTokens = dscEngine.getCollateralTokens();

        wbtc = ERC20Mock(collateralTokens[0]);
        weth = ERC20Mock(collateralTokens[1]);
    }

    // redeem collateral
    function depositCollateral(
        address collateral,
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        dscEngine.depositCollateral(
            address(collateral),
            amountCollateral,
            address(this)
        );
    }

    // Helper function
    function _getCollateralFromSeed(
        uint256 collateralSeed
    ) private view returns (ERC20Mock collateral) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
