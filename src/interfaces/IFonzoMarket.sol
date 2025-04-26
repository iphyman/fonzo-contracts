// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.28;

interface IFonzoMarket {
    /// @dev possible state of a round
    enum Status {
        NOT_OPEN,
        OPEN,
        LIVE,
        RESOLVED,
        REFUNDING
    }

    /// @dev structure for market prediction round
    struct Round {
        /// unix timestamp of when market round entry closes
        uint64 lockTime;
        /// unix timestamp of when market round is due for resolution
        uint64 closingTime;
        /// asset closing price as obtained from the oracle
        int64 closingPrice;
        /// round locked price
        int64 priceMark;
        /// sum of all stakes in this round
        uint128 totalShares;
        /// sum of all bullish positions stakes
        uint128 bullShares;
        /// sum of all bearish positions stakes
        uint128 bearShares;
        /// total amount available for disbursment as reward
        uint128 rewardPool;
        /// total winning stakes
        uint128 winningShares;
        /// the status describing the round state
        Status status;
        /// the winning side
        uint8 winningSide;
    }

    /**
     * @dev State represents a structure for users current
     * prediction
     */
    struct Position {
        // The amount staked as wager for position
        uint240 stake;
        // The user's choice of either `Bearish = 1` or `Bullish = 2`
        uint8 option;
        // True if the option has been exercised or position reward claimed
        bool settled;
    }

    struct RoundInfo {
        /// the round identifier
        uint256 roundId;
        /// unix timestamp of when market round entry closes
        uint64 lockTime;
        /// unix timestamp of when market round is due for resolution
        uint64 closingTime;
        /// asset closing price as obtained from the oracle
        int64 closingPrice;
        /// round locked price
        int64 priceMark;
        /// sum of all stakes in this round
        uint128 totalShares;
        /// sum of all bullish positions stakes
        uint128 bullShares;
        /// sum of all bearish positions stakes
        uint128 bearShares;
        /// total amount available for disbursment as reward
        uint128 rewardPool;
        /// total winning stakes
        uint128 winningShares;
        /// the status describing the round state
        Status status;
        /// the winning side
        uint8 winningSide;
        /// the user position
        Position position;
    }

    /// @notice Thrown when it is too early to resolve round
    error ActionTooEarly();

    /// @notice Thrown if market already exist
    error MarketAlreadyExist();

    /// @notice Thrown when user want to claim reward twice
    error Claimed();

    /// @notice Revert if no reward to claim
    error NoReward();

    /// @notice Revert when trying to interact with non-existing market
    error MarketNotInitialized();

    /// @notice Revert when a round entry is no longer allowed
    error EntryClosed();

    /// @notice Revert when trying to open a position double position
    error PositionExist();

    /// @notice Revert if the position has no stake
    error PositionNotFound();

    /// @notice Revert when stake is zero
    error AmountCannotBeZero();

    /**
     * @notice Called to place a bearish bet on a market
     *
     * @param id the identifier of market to open position in
     * @param roundId the unique id of the active round
     */
    function bearish(bytes21 id, uint256 roundId) external payable;

    /**
     * @notice Called to place a bullish bet on a market
     *
     * @param id the identifier of market to open position in
     * @param roundId the unique id of the active round
     */
    function bullish(bytes21 id, uint256 roundId) external payable;

    /**
     * @dev Allows owner to settle a positions, more like claiming rewards accrued in `roundIds`
     *
     * @param id market identifier
     * @param roundIds array of round identifiers
     */
    function settle(bytes21 id, uint256[] calldata roundIds) external;

    /**
     * @dev Allows anyone to initialize a new market if it's not yet existing
     *
     * @param id FTSO oracle price feed identifier
     */
    function initializeMarket(bytes21 id) external payable;

    /**
     * @dev Allows anyone to resolve a prediction round
     *
     * @param id market identifier
     * @param roundId id of round to finalize
     */
    function resolve(bytes21 id, uint256 roundId) external payable;

    /**
     * @dev Returns market user round position info for UI
     *
     * @param id market identifier
     * @param account user address
     * @param cursor the pagination cursor
     * @return rounds array round position info
     *
     */
    function getAccountRoundsWithPositions(bytes21 id, address account, uint256 cursor)
        external
        view
        returns (RoundInfo[] memory rounds);

    /**
     * @dev Getter function for UI, to fetch markets latest 5 rounds with user position and config
     *
     * @param id unique market identifier
     * @param account address of user positions to fetch
     * @return rounds array of round structs
     * @return roundId the latest round identifier
     */
    function getLatestRoundsWithPosition(bytes21 id, address account)
        external
        view
        returns (RoundInfo[] memory rounds, uint256 roundId);

    /**
     * @dev Getter function to return an array of all created markets
     * @return marketIds Array of market identifiers
     */
    function getMarketIds() external view returns (bytes21[] memory marketIds);
}
