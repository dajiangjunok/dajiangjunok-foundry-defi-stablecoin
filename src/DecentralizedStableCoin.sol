// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStableCoin (去中心化稳定币)
 * @author Alivin (作者：Alivin)
 * Collateral: Exogenous (ETH & BTC) (抵押品：外生性资产(ETH和BTC))
 * Minting: Algorithmic (铸币方式：算法型)
 * Relative Stability: Pegged to USD (相对稳定性：锚定美元)
 *
 * This is the contract meant to be governed by DSCEngine. (该合约由DSCEngine合约进行治理)
 * This contract is just the ERC20 implementation of our stablecoin system. (该合约仅是我们稳定币系统的ERC20实现)
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }

        super.burn(_amount); // 通知父类调用burn函数
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }

        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }

        _mint(_to, _amount); // 调用erc20的_mint函数
        return true;
    }
}
