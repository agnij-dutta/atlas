// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IExecutorReputation {
    // ── Structs ──────────────────────────────────────────────────────────

    struct ExecutorProfile {
        uint128 stake;
        uint128 pendingWithdrawal;
        uint64 registeredAt;
        uint64 withdrawalUnlockTime;
        uint64 totalExecutions;
        uint64 successfulExecutions;
        uint64 failedExecutions;
        uint64 lastActiveAt;
        uint128 cumulativeGasUsed;
        uint128 totalRewardsEarned;
    }

    // ── Events ───────────────────────────────────────────────────────────

    event ExecutorRegistered(address indexed executor, uint128 stake);
    event StakeDeposited(address indexed executor, uint128 amount, uint128 newTotal);
    event WithdrawalRequested(address indexed executor, uint128 amount, uint64 unlockTime);
    event StakeWithdrawn(address indexed executor, uint128 amount);
    event ExecutionRecorded(
        address indexed executor,
        uint256 indexed workflowId,
        bool success,
        uint128 gasUsed
    );
    event ExecutorSlashed(address indexed executor, uint128 amount, bytes32 reason);

    // ── Errors ───────────────────────────────────────────────────────────

    error AlreadyRegistered();
    error NotRegistered();
    error InsufficientStake();
    error BelowMinimumStake();
    error NoWithdrawalPending();
    error WithdrawalLocked(uint64 unlockTime, uint64 currentTime);
    error ZeroAmount();
    error SlashExceedsStake();

    // ── Functions ────────────────────────────────────────────────────────

    function register() external payable;
    function depositStake() external payable;
    function requestWithdrawal(uint128 amount) external;
    function claimWithdrawal() external;
    function recordExecution(address executor, uint256 workflowId, bool success, uint128 gasUsed) external;
    function slash(address executor, uint128 amount, bytes32 reason) external;
    function getReputationScore(address executor) external view returns (uint256);
    function isEligible(address executor) external view returns (bool);
    function getProfile(address executor) external view returns (ExecutorProfile memory);
}
