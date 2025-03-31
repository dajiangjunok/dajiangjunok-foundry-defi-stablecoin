// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";

contract DSCEngine {
    /////////////////////
    // ERROR           //
    /////////////////////
    error DSCEnginen__MustBeMoreThanZero();
    error DSCEnginen__NotAllowedToken();
    error DSCEnginen__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();
    /////////////////////
    // STATE VARIABLEs //
    /////////////////////

    mapping(address token => address priceFeed) private s_priceFeeds;
    DecentralizedStableCoin private immutable i_dsc;

    /////////////////////
    // MODIFIERS       //
    /////////////////////
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEnginen__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _token) {
        // 如果价格提要地址为0，则抛出错误
        if (s_priceFeeds[_token] == address(0)) {
            revert DSCEnginen__NotAllowedToken();
        }
        _;
    }

    /////////////////////
    // FUNCTIONS       //
    /////////////////////
    // 构造函数
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address _dscAddress
    ) {
        // USD price feed address

        // 检查参数长度是否相等
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEnginen__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();
        }

        i_dsc = DecentralizedStableCoin(_dscAddress);
    }

    //////////////////////////////
    // EXTERNAL_FUNCTIONS       //
    //////////////////////////////

    // 抵押并铸造DSC
    function depositCollateralAndMintDsc() external {}

    /**
     * 存入抵押
     * @param _collateralToken 抵押代币的地址
     * @param _collateralAmount 抵押代币的数量
     * @param _borrower 借款人地址
     */
    function depositCollateral(
        address _collateralToken,
        uint256 _collateralAmount,
        address _borrower
    ) external moreThanZero(_collateralAmount) {}

    // 赎回抵押品并销毁DSC
    function redeemCollateralForDsc() external {}

    // 赎回抵押品
    function redeemCollateral() external {}

    // 铸造DSC
    function mintDsc() external {}

    // 销毁DSC
    function burnDsc() external {}

    // 清算
    function liquidate() external {}

    // 计算健康因子
    function getHealthFactor() external view {}
}
