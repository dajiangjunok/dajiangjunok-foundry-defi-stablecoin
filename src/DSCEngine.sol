// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./libraries/OracleLib.sol";

/**
 * @title DSCEngine 去中心化稳定币引擎合约
 * @author Alivin
 * @notice 该合约实现了一个去中心化稳定币系统的核心逻辑
 * @dev 该合约继承了 ReentrancyGuard，用于防止重入攻击
 * @dev 合约主要功能包括:
 * - 存入和赎回抵押品
 * - 铸造和销毁 DSC 稳定币
 * - 清算不良债务
 * - 维护系统的健康因子
 */
contract DSCEngine is ReentrancyGuard {
    /////////////////////
    // ERROR           //
    /////////////////////

    // 当输入金额为0或负数时抛出错误
    error DSCEngine__MustBeMoreThanZero();

    // 当使用未被允许的代币作为抵押品时抛出错误
    error DSCEngine__NotAllowedToken();

    // 当代币地址数组与价格预言机地址数组长度不匹配时抛出错误
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();

    // 当代币转账失败时抛出错误
    error DSCEngine__transferFromFailed();

    // 当健康因子低于最小阈值时抛出错误
    error DSCEngine__HealthFactorIsBroken(uint256 userHealthFactor);

    // 当铸造DSC代币失败时抛出错误
    error DSCEngine__MintFailed();

    // 当销毁DSC代币失败时抛出错误
    error DSCEngine__HealthFactorNotImproved();

    /**
     * @notice 当用户健康因子正常时抛出错误
     * @dev 在尝试清算健康状况良好的用户时会触发此错误
     */
    error DSCEngine__HealthFactorOk();

    /////////////////////
    // TYPES           //
    /////////////////////
    using OracleLib for AggregatorV3Interface;

    /////////////////////
    // STATE VARIABLEs //
    /////////////////////
    /**
     * @notice 喂价精度调整常量
     * @dev 用于调整 Chainlink 价格预言机返回的价格精度
     */
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;

    /**
     * @notice 基础精度常量
     * @dev 用于价格计算的基础精度单位
     */
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // 10% 奖金

    /**
     * @notice 代币地址到价格预言机地址的映射
     * @dev 用于存储每个代币对应的价格预言机地址
     */
    mapping(address token => address priceFeed) private s_priceFeeds;
    //存储所有被允许作为抵押品的代币地址数组
    address[] private s_collateralTokens;

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
    /**
     * @notice 存入抵押品事件
     * @dev 当用户存入抵押品时触发
     * @param user 存入抵押品的用户地址
     * @param collateralToken 抵押品代币地址
     * @param collateralAmount 存入的抵押品数量
     */
    event CollateralDeposited(
        address indexed user,
        address indexed collateralToken,
        uint256 indexed collateralAmount
    );

    /**
     * @notice 赎回抵押品事件
     * @dev 当用户赎回抵押品时触发
     * @param redeemedFrom 赎回抵押品的用户地址
     * @param redeemedTo 赎回抵押品的用户地址
     * @param redeemedCollateralToken 被赎回的抵押品代币地址
     * @param redeemedCollateralAmount 赎回的抵押品数量
     */
    event CollateralRedeemed(
        address indexed redeemedFrom,
        address indexed redeemedTo,
        address indexed redeemedCollateralToken,
        uint256 redeemedCollateralAmount
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

        // 遍历数组，将代币地址和价格预言机地址存入映射
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(_dscAddress);
    }

    //////////////////////////////
    // EXTERNAL_FUNCTIONS       //
    //////////////////////////////

    /**
     * @notice 存入抵押品并铸造DSC代币
     * @param tokenCollateralAddress 抵押品代币地址
     * @param tokenCollateralAmount 抵押品数量
     * @param amountDscToMint 要铸造的DSC代币数量
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 tokenCollateralAmount,
        uint256 amountDscToMint
    ) external {
        depositCollateral(
            tokenCollateralAddress,
            tokenCollateralAmount,
            msg.sender
        );
        mintDsc(amountDscToMint);
    }

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
        public
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

    /**
     * @notice 赎回抵押品并销毁DSC代币
     * @dev 该函数允许用户同时执行两个操作:
     * 1. 销毁指定数量的DSC代币
     * 2. 赎回指定数量的抵押品
     * @dev 函数会自动检查操作后的健康因子是否满足要求
     * @param tokenCollateralAddress 要赎回的抵押品代币地址
     * @param amountCollateral 要赎回的抵押品数量
     * @param amountDscToBurn 要销毁的DSC代币数量
     */
    function redeemCollateralForDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToBurn
    ) external {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // redeemCollateral already checks for health factor
    }

    /**
     * @notice 赎回抵押品
     * @notice 1. 他们的HealthFactor 必须高于1
     * @notice 2. 可以部分赎回
     * @param tokenCollateralAddress 抵押品代币地址
     * @param amountCollateral 要赎回的抵押品数量
     */

    // CEI: check - effect - interaction
    function redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) public moreThanZero(amountCollateral) nonReentrant {
        _redeemCollateral(
            tokenCollateralAddress,
            amountCollateral,
            msg.sender,
            msg.sender
        );
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // $100 ETH -> $20DSC 【质押100美金以太坊，借贷出20美金DSC】
    // 100 break 【想要赎回100美金的ETH】
    // 1.burn DSC 【 销毁DSC 】
    // 2.redeem ETH 【 赎回ETH 】

    /**
     * @notice 铸造DSC
     * @notice 检查抵押品价值是否大于DSC数量，PriceFeeds ,check value
     * @param amountDscToMint 需要铸造的DSC数量
     *
     */
    function mintDsc(
        uint256 amountDscToMint
    ) public moreThanZero(amountDscToMint) nonReentrant {
        // 记录用户铸造的DSC数量，存入映射
        s_DSCMinded[msg.sender] += amountDscToMint;

        // 一旦抵押品价值低于铸造的DSC数量回滚
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    // 销毁DSC
    function burnDsc(uint256 amount) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // $100 ETH -> $50DSC
    // $20 eth back $50 DSC
    // 清算
    function liquidate(
        address collateral, // 抵押品代币地址
        address user, // 被清算的用户地址
        uint debtToCover // 需要清算的债务数量
    ) external moreThanZero(debtToCover) nonReentrant {
        // need to check health factor of user
        // CEI
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(
            collateral,
            debtToCover
        );
        uint256 bonusCollateral = (tokenAmountFromDebtCovered *
            LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered +
            bonusCollateral;

        _redeemCollateral(
            collateral,
            totalCollateralToRedeem,
            user,
            msg.sender
        );
        _burnDsc(debtToCover, user, address(this));
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // 计算健康因子
    function getHealthFactor() external view {}

    //////////////////////////////////////
    //  PRIVATE_INTERNAL_VIEW_FUNCTIONS //
    //////////////////////////////////////

    function _burnDsc(
        uint256 amountDscToBurn,
        address onBehalfOf,
        address dscFrom
    ) private {
        s_DSCMinded[onBehalfOf] -= amountDscToBurn;
        // _revertIfHealthFactorIsBroken(msg.sender);
        bool success = i_dsc.transferFrom(
            dscFrom,
            address(this),
            amountDscToBurn
        );
        // this conditional is hypothetically unnecessary
        if (success) {
            revert DSCEngine__transferFromFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    /**
     * @notice 内部函数，用于赎回抵押品
     * @dev 从用户账户中扣除抵押品，并将抵押品转移给指定地址
     * @param tokenCollateralAddress 抵押品代币地址
     * @param amountCollateral 要赎回的抵押品数量
     * @param from 赎回抵押品的来源地址
     * @param to 接收抵押品的目标地址
     */
    function _redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        address from,
        address to
    ) private {
        s_collateralDeposited[to][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(
            from,
            to,
            tokenCollateralAddress,
            amountCollateral
        );
        // _collateralHealthFactor()
        bool success = IERC20(tokenCollateralAddress).transfer(
            to,
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__transferFromFailed();
        }
    }

    /**
     * @notice 获取用户账户信息
     * @dev 返回用户铸造的DSC数量和抵押品的美元价值
     * @param user 用户地址
     * @return totalDscMinted 用户铸造的DSC总量
     * @return collateralValueInUsd 用户抵押品的美元价值
     */
    function _getUserAccountInformation(
        address user
    )
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        // 1. 获取用户铸造的DSC数量
        totalDscMinted = s_DSCMinded[user];
        // 2. 获取用户抵押品的价值
        collateralValueInUsd = getAccountCollateralValue(user);

        // 3. 返回用户的DSC数量和抵押品价值
    }

    /**
     * @notice 计算用户的健康因子，如果健康因子小于1，则调用 liquidate() 函数
     * @param user 用户地址
     * @return 用户的健康因子
     */
    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted DSC的总价值
        // total collateral value 抵押物的总价值
        (
            uint256 totalDscMinted,
            uint256 collateralValueInUsd
        ) = _getUserAccountInformation(user);
        if (totalDscMinted == 0) return type(uint256).max; // 如果未铸造DSC，返回最大值表示极其健康
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        // 1000ETH  1000 * 50 = 5000  ;  50000 / 100 = 500
        // 150 * 50 = 7500  ;  7500 / 100 = 75
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    // 1. 检查用户的健康因子
    // 2. 如果健康因子低于1，那么就抛出错误
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsBroken(userHealthFactor);
        }
    }

    //////////////////////////////////////
    //  PUBLIC_EXTERNAL_VIEW_FUNCTIONS  //
    //////////////////////////////////////
    /**
     * @notice 根据美元金额计算对应的代币数量
     * @param token 代币地址
     * @param usdAmountInWei 美元金额(以Wei为单位)
     * @return 对应的代币数量
     */
    function getTokenAmountFromUsd(
        address token,
        uint256 usdAmountInWei
    ) public view returns (uint256) {
        // 1. 获取价格预言机地址
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, uint256 price, , , ) = priceFeed.staleCheckLatestRoundData();
        // 2. 计算对应的代币数量
        // 3. 精度调整
        // ($10e18 * 1e18) / ($2000e8 * 1e10) =   5e15
        // 5,000,000,000,000,000
        return
            (usdAmountInWei * PRECISION) /
            (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    /**
     * @notice 获取用户抵押品的总价值
     * @param user 用户地址
     *
     */
    function getAccountCollateralValue(
        address user
    ) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    /**
     * @notice 获取代币的美元价值
     * @param token 代币地址
     * @param amount 代币数量
     * @return 代币的美元价值
     */
    function getUsdValue(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, uint256 price, , , ) = priceFeed.staleCheckLatestRoundData();
        // 1 ETH = $1000
        // The returned value from Chainlink is 8 decimals

        return
            (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
    }

    function getAccountInformation(
        address user
    )
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        return _getUserAccountInformation(user);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }
}
