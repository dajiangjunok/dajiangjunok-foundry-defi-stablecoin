// Hove our invariant aka properties
// What are our invariants?

// 1.DSC 总供应量应该小于质押品的总价值

// 2. getter view function should never revert <- evergreen invariant

pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelpConfig.s.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployDecentralizedStableCoin deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;

    function setUp() external {
        deployer = new DeployDecentralizedStableCoin();
        (dsc, dscEngine, config) = deployer.run();

        targetContract(address(dscEngine));
    }
}
