// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @dev This library is used to check the Chainlink Oracle for stale data
 * If a price is stale, the function will revert and render the DSCEngine unusable
 * @author @Alivin
 */
library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(
        AggregatorV3Interface priceFeed
    ) public view returns (uint80, uint256, uint256, uint256, uint80) {
        priceFeed.latestRoundData();
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert OracleLib__StalePrice();
        return (
            roundId,
            uint256(answer),
            startedAt,
            updatedAt,
            answeredInRound
        );
    }
}
