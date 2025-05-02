// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.28;

import {FtsoV2Interface} from "./interfaces/FtsoV2Interface.sol";
import {IFonzoMarket} from "./interfaces/IFonzoMarket.sol";

contract FonzoMarket is IFonzoMarket {
    uint16 internal constant BASIS_POINT = 10_000; // 100%
    uint16 internal constant PROTOCOL_FEE_BPS = 1_000; // 10%
    uint256 public constant DURATION = 5 minutes;

    struct MarketInfo {
        /// keeps track of market last round id
        uint256 roundId;
        /// FTSO oracle price feed identifier
        bytes32 oracleId;
        /// keeps track of users positions in this market
        mapping(bytes32 positionId => Position) positions;
        /// keeps track of market rounds
        mapping(uint256 roundId => Round) rounds;
        /// Kepps track of users roundIds
        mapping(address account => uint256[]) myRoundIds;
    }

    /// @dev Store the FTSOV2 contract
    FtsoV2Interface public immutable ftsoV2;

    /// @dev Store the contract owner for authentication to collect fees
    address public owner;

    /// @dev Store the fees accrued to protocol
    uint256 public protocolFeesAccrued;

    /// @dev Keep track of each markets data
    mapping(bytes21 id => MarketInfo market) private _markets;

    /// @dev Keep track of initialized market feed ids
    bytes21[] private _marketIds;

    constructor(address _owner, address _ftsoV2) {
        ftsoV2 = FtsoV2Interface(_ftsoV2);
        owner = _owner;
    }

    /// @inheritdoc IFonzoMarket
    function bearish(bytes21 id, uint256 roundId) external payable override {
        _predit(id, roundId, msg.sender, uint128(msg.value), Option.DOWN);
    }

    /// @inheritdoc IFonzoMarket
    function bullish(bytes21 id, uint256 roundId) external payable override {
        _predit(id, roundId, msg.sender, uint128(msg.value), Option.UP);
    }

    /// @inheritdoc IFonzoMarket
    function settle(bytes21 id, uint256[] calldata roundIds) external override {
        uint256 reward;

        for (uint256 i = 0; i < roundIds.length; i++) {
            reward += _settle(id, roundIds[i], msg.sender);
        }

        /// @dev Transfer reward to caller
        payable(address(msg.sender)).transfer(reward);
    }

    /// @inheritdoc IFonzoMarket
    function initializeMarket(bytes21 id) external payable override {
        MarketInfo storage market = _markets[id];

        // ensure market does not exist already
        if (market.oracleId != bytes21(0)) revert MarketAlreadyExist();
        market.oracleId = id;
        _marketIds.push(id);

        // ensure price feed exists for the new market been created
        uint256 _fee = ftsoV2.calculateFeeById(id);
        if (msg.value < _fee) revert InsufficientFee();

        /// @dev TODO: we should probably check the returned value to ensure it's a valid feed
        (uint256 price,,) = ftsoV2.getFeedById(id);

        // Initialize and lock the genesis round
        _startNextRound(market, id);
        _lockMarketRound(market, id, 1, uint64(price));

        // start n + 1 round to maintain the loop
        _startNextRound(market, id);
    }

    /// @inheritdoc IFonzoMarket
    function resolve(bytes21 id, uint256 roundId) external payable override {
        MarketInfo storage market = _markets[id];
        Round storage round = market.rounds[roundId];

        // ensure round status can be resolved
        if (round.status != Status.LIVE) revert InvalidRoundStatus();

        // ensure the timing is right
        if (round.closingTime > block.timestamp) revert ActionTooEarly();

        uint256 _fee = ftsoV2.calculateFeeById(id);
        if (msg.value < _fee) revert InsufficientFee();

        (uint256 price,,) = ftsoV2.getFeedById(id);
        uint64 closingPrice = uint64(price);

        // lock the following n + 1 round
        _lockMarketRound(market, id, roundId + 1, closingPrice);
        // start another n + 2 round
        _startNextRound(market, id);

        // only collect protocol fee when position exists on both sides
        round.closingPrice = closingPrice;
        round.status = Status.RESOLVED;

        uint128 protocolFee;
        uint128 rewardBase;
        uint128 resolverFee;
        bool isHouseWin;

        // if closing price greater than locked price, market was bullish, the bulls wins
        if (closingPrice > round.priceMark) {
            round.winningShares = round.bullShares;
            round.winningSide = Option.UP;
            round.rewardPool = round.totalShares;
            rewardBase = round.bearShares;
            isHouseWin = round.bearShares > 0 && round.bullShares == 0;
            // if closing price less than locked price, market was bearish, the bears wins
        } else if (closingPrice < round.priceMark) {
            round.winningShares = round.bearShares;
            round.winningSide = Option.DOWN;
            round.rewardPool = round.totalShares;
            rewardBase = round.bullShares;
            isHouseWin = round.bullShares > 0 && round.bearShares == 0;
        }

        if (round.bearShares > 0 && round.bullShares > 0) {
            protocolFee = (rewardBase * PROTOCOL_FEE_BPS) / BASIS_POINT;
            resolverFee = (protocolFee * PROTOCOL_FEE_BPS) / BASIS_POINT;
            round.rewardPool = round.totalShares - protocolFee;
            // account for fee
            protocolFeesAccrued += protocolFee - resolverFee;
        }

        if (isHouseWin) {
            // the house wins
            if (round.totalShares > 0) {
                resolverFee = (round.totalShares * PROTOCOL_FEE_BPS) / BASIS_POINT;
                protocolFeesAccrued += round.totalShares - resolverFee;
            }
        }

        if (resolverFee > 0) payable(address(msg.sender)).transfer(resolverFee);
        emit Resolve(id, roundId, closingPrice, round.rewardPool, round.winningShares, round.winningSide, resolverFee);
    }

    /**
     * ===================================== Getter Functions =====================================
     */
    /// @inheritdoc IFonzoMarket
    function getPositions(bytes21 id, address account, uint256[] calldata roundIds)
        external
        view
        override
        returns (RoundInfo[] memory rounds)
    {
        rounds = new RoundInfo[](roundIds.length);
        MarketInfo storage market = _markets[id];

        for (uint256 i = 0; i < roundIds.length; i++) {
            uint256 roundId = roundIds[i];
            Round memory round = market.rounds[roundId];

            bytes32 positionId = keccak256(abi.encodePacked(id, roundId, account));
            Position memory position = market.positions[positionId];
            rounds[i] = RoundInfo(
                roundId,
                round.lockTime,
                round.closingTime,
                round.closingPrice,
                round.priceMark,
                round.totalShares,
                round.bullShares,
                round.bearShares,
                round.rewardPool,
                round.winningShares,
                round.status,
                round.winningSide,
                position
            );
        }
    }

    /// @inheritdoc IFonzoMarket
    function getMyRoundIds(bytes21 id, address account) external view override returns (uint256[] memory roundIds) {
        MarketInfo storage market = _markets[id];
        roundIds = new uint256[](market.myRoundIds[account].length);
        roundIds = market.myRoundIds[account];
    }

    /// @inheritdoc IFonzoMarket
    function getLatestRoundsWithPosition(bytes21 id, address account, uint256 numOfRounds)
        external
        view
        override
        returns (RoundInfo[] memory rounds, uint256 roundId)
    {
        MarketInfo storage market = _markets[id];
        roundId = market.roundId;

        numOfRounds = numOfRounds == 0 ? 5 : numOfRounds;
        uint256 len = roundId > numOfRounds ? numOfRounds : roundId;
        rounds = new RoundInfo[](len);

        for (uint256 i = 0; i < len; i++) {
            uint256 rId = roundId - i;
            Round memory round = market.rounds[rId];

            bytes32 positionId = keccak256(abi.encodePacked(id, rId, account));
            Position memory position = market.positions[positionId];
            rounds[i] = RoundInfo(
                rId,
                round.lockTime,
                round.closingTime,
                round.closingPrice,
                round.priceMark,
                round.totalShares,
                round.bullShares,
                round.bearShares,
                round.rewardPool,
                round.winningShares,
                round.status,
                round.winningSide,
                position
            );
        }
    }

    /// @inheritdoc IFonzoMarket
    function getMarketIds() external view override returns (bytes21[] memory marketIds) {
        marketIds = new bytes21[](_marketIds.length);
        marketIds = _marketIds;
    }

    /**
     * ===================================== Internal Functions ==================================
     */
    function _startNextRound(MarketInfo storage market, bytes21 id) private {
        uint256 roundId = ++market.roundId;

        uint64 lockTime = uint64(block.timestamp + DURATION);
        uint64 closingTime = uint64(block.timestamp + (DURATION * 2));

        Round storage round = market.rounds[roundId];
        round.status = Status.OPEN;
        round.lockTime = lockTime;
        round.closingTime = closingTime;

        emit NewRound(id, roundId, lockTime, closingTime);
    }

    function _lockMarketRound(MarketInfo storage market, bytes21 id, uint256 roundId, uint64 price) private {
        Round storage round = market.rounds[roundId];
        uint64 closingTime = uint64(block.timestamp + DURATION);
        round.status = Status.LIVE;
        round.closingTime = closingTime;
        round.priceMark = price;

        emit LockedPrice(id, roundId, price, closingTime);
    }

    function _predit(bytes21 id, uint256 roundId, address account, uint128 stake, Option option)
        private
        returns (bytes32 positionId)
    {
        MarketInfo storage market = _markets[id];
        Round storage round = market.rounds[roundId];

        // ensure market is initialized
        if (market.oracleId == bytes21(0)) revert MarketNotInitialized();
        // ensure round entry is open
        if (block.timestamp > round.lockTime) revert EntryClosed();

        // ensure stake is not zero
        if (stake == 0) revert AmountCannotBeZero();

        positionId = keccak256(abi.encodePacked(id, roundId, account));
        Position storage position = market.positions[positionId];

        // ensure user has no previous position
        if (position.stake > 0) revert PositionExist();

        // if all checks well, open position
        // probably not going to overflow, even if Elon Musk stakes all his wealth, LOL!
        unchecked {
            round.totalShares += stake;

            if (option == Option.UP) {
                round.bullShares += stake;
            } else {
                round.bearShares += stake;
            }
        }

        market.myRoundIds[account].push(roundId);
        position.stake = stake;
        position.option = option;

        emit Predicted(id, roundId, account, positionId, option, stake);
    }

    function _settle(bytes21 id, uint256 roundId, address account) private returns (uint256 reward) {
        MarketInfo storage market = _markets[id];
        Round storage round = market.rounds[roundId];

        bytes32 positionId = keccak256(abi.encodePacked(id, roundId, account));
        Position storage position = market.positions[positionId];

        // ensure user has a valid position
        if (position.stake == 0) revert PositionNotFound();
        // ensure user has not claimed reward already
        if (position.settled) revert Claimed();

        // tag claimed to avoid reentrancy
        position.settled = true;
        bool isRewardable = round.winningSide == position.option;

        if (round.status == Status.RESOLVED && isRewardable) {
            reward = (position.stake * round.rewardPool) / round.winningShares;
        } else if (round.status == Status.REFUNDING) {
            reward = position.stake;
        } else {
            revert NoReward();
        }

        emit Claim(id, roundId, account, positionId, reward);
    }
}
