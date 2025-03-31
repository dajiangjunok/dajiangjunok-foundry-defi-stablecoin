// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DSCEngine is ReentrancyGuard {
    /////////////////////
    // ERROR           //
    /////////////////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();
    error DSCEngine__transferFromFailed();

    /////////////////////
    // STATE VARIABLEs //
    /////////////////////
    /**
     * @notice 代币地址到价格预言机地址的映射
     * @dev 用于存储每个代币对应的价格预言机地址
     */
    mapping(address token => address priceFeed) private s_priceFeeds;

    /**
     * @notice 用户抵押品映射
     * @dev 记录每个用户存入的各种代币数量
     * @dev 第一个mapping的key是用户地址，第二个mapping的key是代币地址，value是抵押数量
     */
    mapping(address user => mapping(address token => uint256 amount))
        private s_collateralDeposited;

    /**
     * @notice 用户铸造的DSC代币映射
     * @dev 记录每个用户铸造的DSC代币数量
     * @dev mapping的key是用户地址，value是铸造的DSC数量
     */
    mapping(address user => uint256 amountDscMinted) private s_DSCMinded;

    /**
     * @notice DSC代币合约实例
     * @dev 不可变的DSC代币合约引用
     */
    DecentralizedStableCoin private immutable i_dsc;

    /////////////////////
    // EVENT           //
    /////////////////////
    event CollateralDeposited(
        address indexed user,
        address indexed collateralToken,
        uint256 indexed collateralAmount
    );

    /////////////////////
    // MODIFIERS       //
    /////////////////////
    /**
     * @notice 检查输入金额是否大于0
     * @param _amount 需要检查的金额
     */
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    /**
     * @notice 检查代币是否被允许作为抵押品
     * @param _token 需要检查的代币地址
     */
    modifier isAllowedToken(address _token) {
        // 如果价格提要地址为0，则抛出错误
        if (s_priceFeeds[_token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    /////////////////////
    // FUNCTIONS       //
    /////////////////////
    // 构造函数
    /**
     * @notice 构造函数初始化代币地址和价格预言机地址
     * @param tokenAddresses 代币地址数组
     * @param priceFeedAddresses 价格预言机地址数组
     * @param _dscAddress DSC代币地址
     */
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address _dscAddress
    ) {
        // USD price feed address

        // 检查参数长度是否相等
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();
        }

        i_dsc = DecentralizedStableCoin(_dscAddress);
    }

    //////////////////////////////
    // EXTERNAL_FUNCTIONS       //
    //////////////////////////////

    // 抵押并铸造DSC
    function depositCollateralAndMintDsc() external {}

    /**
     * @notice CEI 检查-影响-交互
     * 存入抵押
     * @param _collateralToken 抵押代币的地址
     * @param _collateralAmount 抵押代币的数量
     * @param _borrower 借款人地址
     */
    function depositCollateral(
        address _collateralToken,
        uint256 _collateralAmount,
        address _borrower
    )
        external
        moreThanZero(_collateralAmount)
        isAllowedToken(_collateralToken)
        nonReentrant // 防止重入攻击
    {
        // 存入抵押
        s_collateralDeposited[_borrower][_collateralToken] += _collateralAmount;
        // 发送事件
        emit CollateralDeposited(
            _borrower,
            _collateralToken,
            _collateralAmount
        );
        bool isSuccess = IERC20(_collateralToken).transferFrom(
            _borrower,
            address(this),
            _collateralAmount
        );

        if (!isSuccess) {
            revert DSCEngine__transferFromFailed();
        }
    }

    // 赎回抵押品并销毁DSC
    function redeemCollateralForDsc() external {}

    // 赎回抵押品
    function redeemCollateral() external {}

    //

    /**
     * @notice 铸造DSC
     * @notice 检查抵押品价值是否大于DSC数量，PriceFeeds ,check value
     * @param amountDscToMint 需要铸造的DSC数量
     *
     */
    function mintDsc(
        uint256 amountDscToMint
    ) external moreThanZero(amountDscToMint) nonReentrant {
        // 记录用户铸造的DSC数量，存入映射
        s_DSCMinded[msg.sender] += amountDscToMint;

        // 一旦抵押品价值低于铸造的DSC数量回滚
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // 销毁DSC
    function burnDsc() external {}

    // 清算
    function liquidate() external {}

    // 计算健康因子
    function getHealthFactor() external view {}

    //////////////////////////////////////
    //  PRIVATE_INTERNAL_VIEW_FUNCTIONS //
    //////////////////////////////////////

    function _getUserAccountInformation(
        address user
    )
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        // 1. 获取用户铸造的DSC数量
        // 2. 获取用户抵押品的价值
        // 3. 返回用户的DSC数量和抵押品价值
    }

    /**
     * @notice 计算用户的健康因子，如果健康因子小于1，则调用 liquidate() 函数
     * @param user 用户地址
     */
    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted DSC的总价值
        // total collateral value 抵押物的总价值
        (
            uint256 totalDscMinted,
            uint256 collateralValueInUsd
        ) = _getUserAccountInformation(user);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1. 检查用户的健康因子
        // 2. 如果健康因子低于1，那么就抛出错误
    }
}
