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

    /// @dev Possible position options
    enum Option {
        NONE,
        DOWN,
        UP
    }

    /// @dev structure for market prediction round
    struct Round {
        /// unix timestamp of when market round entry closes
        uint64 lockTime;
        /// unix timestamp of when market round is due for resolution
        uint64 closingTime;
        /// asset closing price as obtained from the oracle
        uint64 closingPrice;
        /// round locked price
        uint64 priceMark;
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
        Option winningSide;
    }

    /**
     * @dev State represents a structure for users current
     * prediction
     */
    struct Position {
        // The amount staked as wager for position
        uint240 stake;
        // The user's choice of either `Bearish = 1` or `Bullish = 2`
        Option option;
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
        uint64 closingPrice;
        /// round locked price
        uint64 lockedPrice;
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
        Option winningSide;
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

    /// @notice Revert when insufficient fee is provided to call FTSO
    error InsufficientFee();

    /// @notice Revert when round status is invalid for an action to be performed
    error InvalidRoundStatus();

    /// @notice Emitted whenever a user makes a prediction on a market price movement
    event Predicted(
        bytes21 indexed marketId,
        uint256 indexed roundId,
        address indexed account,
        bytes32 positionId,
        Option option,
        uint256 betAmount
    );

    /// @notice Emitted whenever a user claims reward
    event Claim(
        bytes21 indexed marketId, uint256 indexed roundId, address indexed account, bytes32 positionId, uint256 amount
    );

    /// @notice Emitted whenever a market round is resolved
    event Resolve(
        bytes21 indexed marketId,
        uint256 indexed roundId,
        uint256 closePrice,
        uint256 rewardPool,
        uint256 winningShares,
        Option winningSide,
        uint256 resolverReward
    );

    /// @notice Emitted whenever a new round  starts
    event NewRound(bytes21 indexed marketId, uint256 indexed roundId, uint256 lockTime, uint256 closingTime);

    /// @notice Emitted whenever a rounds price is locked
    event LockedPrice(bytes21 indexed marketId, uint256 indexed roundId, uint256 lockedPrice, uint256 closingTime);

    /// @notice Emitted whenever a new market is initialized
    event InitializedMarket(bytes21 indexed id, address indexed creator);

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
     * @param roundIds array of rounds to fetch positions
     * @return rounds array round position info
     *
     */
    function getPositions(bytes21 id, address account, uint256[] calldata roundIds)
        external
        view
        returns (RoundInfo[] memory rounds);

    /**
     * @dev Returns market user round ids info for UI
     *
     * @param id market identifier
     * @param account user address
     * @return roundIds array round roundIds
     *
     */
    function getMyRoundIds(bytes21 id, address account) external view returns (uint256[] memory roundIds);

    /**
     * @dev Getter function for UI, to fetch markets latest n rounds with user position and config
     *
     * @param id unique market identifier
     * @param account address of user positions to fetch
     * @param numOfRounds;
     * @return rounds array of round structs
     * @return roundId the latest round identifier
     */
    function getLatestRoundsWithPosition(bytes21 id, address account, uint256 numOfRounds)
        external
        view
        returns (RoundInfo[] memory rounds, uint256 roundId);

    /**
     * @dev Getter function to return an array of all created markets
     * @return marketIds Array of market identifiers
     */
    function getMarketIds() external view returns (bytes21[] memory marketIds);
}
