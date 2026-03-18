// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IPriceOracle.sol";
import "../interfaces/IChainlinkPriceFeed.sol";
import "@chainlink/contracts/src/v0.8/datastreams/DataStreamsVerifierInterface.sol";

contract ChainlinkPriceFeed is IPriceFeed {
    address public owner;
    mapping(string => address) public symbolToFeed;  // symbol => Chainlink 聚合器地址

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function setFeed(string memory symbol, address feedAddress) external onlyOwner {
        require(feedAddress != address(0), "Invalid feed");
        if (symbolToFeed[symbol] == address(0)) {
            // 新符号可加入 supportedSymbols 等
        }
        symbolToFeed[symbol] = feedAddress;
    }

    function getPrice(OperationParams calldata params) external view override returns (OperationResult memory) {
        address feedAddr = symbolToFeed[params.symbol];
        if (feedAddr == address(0)) {
            return OperationResult(0, 0, 0, 0, false, "Feed not found");
        }

        (, int256 price, , uint256 updatedAt,) = AggregatorV3Interface(feedAddr).latestRoundData();
         (price, timestamp) = DataStreamsVerifierInterface(VERIFIER_ADDRESS).getLatestPrice(AAPL_STREAM_ID);
        
        uint8 decimals = AggregatorV3Interface(feedAddr).decimals();

        // 转为 18 位精度（与 Pyth/RedStone 一致）
        uint256 price18 = uint256(price) * (10 ** (18 - decimals));

        // 价格有效性：1 小时内更新过
        bool valid = price > 0 && (block.timestamp - updatedAt) < 3600;

        return OperationResult({
            price: price18,
            minPrice: 0,
            maxPrice: 0,
            publishTime: updatedAt,
            success: valid,
            errorMessage: valid ? "" : "Stale price"
        });
    }
}