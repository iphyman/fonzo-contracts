// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.28;

import {FtsoV2Interface} from "../src/interfaces/FtsoV2Interface.sol";

contract MockFtsoV2 is FtsoV2Interface {
    bytes21 private constant BTC_USD_ID = 0x014254432f55534400000000000000000000000000; // BTC/USD
    bytes21 private constant FLR_USD_ID = 0x01464c522f55534400000000000000000000000000; // FLR/USD

    struct Feed {
        uint256 value;
        int8 decimals;
        uint64 publishTime;
    }

    mapping(bytes21 feedId => Feed feed) public feeds;

    constructor() {}

    function updateFeed(bytes21 id, uint256 value, int8 decimals, uint64 publishTime) external {
        feeds[id] = Feed(value, decimals, publishTime);
    }

    function getFtsoProtocolId() external pure override returns (uint256) {
        return 1;
    }

    function getSupportedFeedIds() external pure override returns (bytes21[] memory _feedIds) {
        _feedIds = new bytes21[](2);
        _feedIds[0] = FLR_USD_ID;
        _feedIds[1] = BTC_USD_ID;
    }

    function getFeedIdChanges() external view override returns (FeedIdChange[] memory _feedIdChanges) {}

    function calculateFeeById(bytes21) external pure override returns (uint256 _fee) {
        _fee = 0;
    }

    function calculateFeeByIds(bytes21[] memory) external pure override returns (uint256 _fee) {
        _fee = 0;
    }

    function getFeedById(bytes21 _feedId)
        external
        payable
        override
        returns (uint256 _value, int8 _decimals, uint64 _timestamp)
    {
        Feed memory feed = feeds[_feedId];
        _value = feed.value;
        _decimals = feed.decimals;
        _timestamp = feed.publishTime;
    }

    function getFeedsById(bytes21[] memory _feedIds)
        external
        payable
        override
        returns (uint256[] memory _values, int8[] memory _decimals, uint64 _timestamp)
    {}

    function getFeedByIdInWei(bytes21 _feedId) external payable override returns (uint256 _value, uint64 _timestamp) {}

    function getFeedsByIdInWei(bytes21[] memory _feedIds)
        external
        payable
        override
        returns (uint256[] memory _values, uint64 _timestamp)
    {}

    function verifyFeedData(FeedDataWithProof calldata _feedData) external view returns (bool) {}
}
