// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IExecutorReputation} from "../interfaces/IExecutorReputation.sol";
import {AtlasAccessControl} from "../access/AtlasAccessControl.sol";

/// @title ExecutorReputation
/// @notice UUPS-upgradeable contract that tracks executor performance, manages staking,
///         and computes on-chain reputation scores for the Atlas execution marketplace.
/// @dev Inherits AtlasAccessControl for UUPS + Ownable + executor role management.
///      Only the ExecutionEngine (granted executor role) may call recordExecution.
///      Only the engine or owner may slash an executor.
contract ExecutorReputation is IExecutorReputation, AtlasAccessControl {
    // ── Constants ────────────────────────────────────────────────────────

    /// @notice Minimum ETH stake required to register as an executor
    uint128 public constant MIN_STAKE = 0.01 ether;

    /// @notice Delay between requesting a withdrawal and being able to claim it
    uint64 public constant WITHDRAWAL_DELAY = 7 days;

    /// @notice Maximum reputation score (basis points)
    uint256 public constant MAX_SCORE = 10_000;

    // ── Storage ──────────────────────────────────────────────────────────

    /// @notice Executor address => profile
    mapping(address => ExecutorProfile) private _profiles;

    // ── Initializer ──────────────────────────────────────────────────────

    /// @notice Initialize the contract behind a UUPS proxy
    /// @param owner_ Protocol admin address
    function initialize(address owner_) external initializer {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
    }

    // ── Registration & Staking ───────────────────────────────────────────

    /// @notice Register as an executor by staking at least MIN_STAKE ETH
    function register() external payable {
        ExecutorProfile storage p = _profiles[msg.sender];
        if (p.registeredAt != 0) revert AlreadyRegistered();
        if (msg.value < MIN_STAKE) revert BelowMinimumStake();

        p.stake = uint128(msg.value);
        p.registeredAt = uint64(block.timestamp);
        p.lastActiveAt = uint64(block.timestamp);

        emit ExecutorRegistered(msg.sender, uint128(msg.value));
    }

    /// @notice Deposit additional ETH stake
    function depositStake() external payable {
        ExecutorProfile storage p = _profiles[msg.sender];
        if (p.registeredAt == 0) revert NotRegistered();
        if (msg.value == 0) revert ZeroAmount();

        p.stake += uint128(msg.value);

        emit StakeDeposited(msg.sender, uint128(msg.value), p.stake);
    }

    /// @notice Request a withdrawal — starts the 7-day lockup timer
    /// @param amount Amount of stake to withdraw (in wei)
    function requestWithdrawal(uint128 amount) external {
        ExecutorProfile storage p = _profiles[msg.sender];
        if (p.registeredAt == 0) revert NotRegistered();
        if (amount == 0) revert ZeroAmount();
        if (amount > p.stake) revert InsufficientStake();

        // Move from active stake to pending
        p.stake -= amount;
        p.pendingWithdrawal += amount;
        p.withdrawalUnlockTime = uint64(block.timestamp) + WITHDRAWAL_DELAY;

        emit WithdrawalRequested(msg.sender, amount, p.withdrawalUnlockTime);
    }

    /// @notice Claim a previously requested withdrawal after the lockup period
    function claimWithdrawal() external {
        ExecutorProfile storage p = _profiles[msg.sender];
        if (p.pendingWithdrawal == 0) revert NoWithdrawalPending();
        if (uint64(block.timestamp) < p.withdrawalUnlockTime) {
            revert WithdrawalLocked(p.withdrawalUnlockTime, uint64(block.timestamp));
        }

        uint128 amount = p.pendingWithdrawal;
        p.pendingWithdrawal = 0;
        p.withdrawalUnlockTime = 0;

        emit StakeWithdrawn(msg.sender, amount);

        // Interaction last — checks-effects-interactions
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    // ── Execution Recording ──────────────────────────────────────────────

    /// @notice Record an execution result for an executor. Only callable by the engine.
    /// @param executor The executor who performed the step
    /// @param workflowId The workflow that was executed
    /// @param success Whether the execution succeeded
    /// @param gasUsed Gas consumed by the execution
    function recordExecution(
        address executor,
        uint256 workflowId,
        bool success,
        uint128 gasUsed
    ) external onlyExecutor {
        ExecutorProfile storage p = _profiles[executor];
        // Allow recording even if not formally registered — the engine decides who executes

        p.totalExecutions += 1;
        if (success) {
            p.successfulExecutions += 1;
        } else {
            p.failedExecutions += 1;
        }
        p.cumulativeGasUsed += gasUsed;
        p.lastActiveAt = uint64(block.timestamp);

        emit ExecutionRecorded(executor, workflowId, success, gasUsed);
    }

    // ── Slashing ─────────────────────────────────────────────────────────

    /// @notice Slash an executor's stake. Only callable by engine (executor role) or owner.
    /// @param executor The executor to slash
    /// @param amount Amount of stake to burn
    /// @param reason A bytes32 tag describing the slash reason
    function slash(address executor, uint128 amount, bytes32 reason) external {
        // Only engine (onlyExecutor) or owner
        if (!executors[msg.sender] && msg.sender != owner()) {
            revert NotExecutor();
        }

        ExecutorProfile storage p = _profiles[executor];
        if (amount > p.stake) revert SlashExceedsStake();

        p.stake -= amount;

        emit ExecutorSlashed(executor, amount, reason);

        // Slashed ETH is burned (sent to address(0) is wasteful; just keep in contract as protocol revenue)
    }

    // ── View Functions ───────────────────────────────────────────────────

    /// @notice Compute a reputation score for an executor (0 to 10000 basis points)
    /// @dev Scoring weights: success rate 60%, activity/uptime 20%, stake amount 20%
    /// @param executor The executor to score
    /// @return score Reputation score in basis points
    function getReputationScore(address executor) external view returns (uint256 score) {
        ExecutorProfile storage p = _profiles[executor];
        if (p.registeredAt == 0) return 0;

        // --- Success rate component (60% weight = 6000 max) ---
        uint256 successComponent;
        if (p.totalExecutions > 0) {
            successComponent = (uint256(p.successfulExecutions) * 6000) / uint256(p.totalExecutions);
        }

        // --- Activity component (20% weight = 2000 max) ---
        // Based on recency: full score if active in last 24h, linearly decays to 0 over 30 days
        uint256 activityComponent;
        if (p.lastActiveAt > 0) {
            uint256 elapsed = block.timestamp - uint256(p.lastActiveAt);
            if (elapsed < 1 days) {
                activityComponent = 2000;
            } else if (elapsed < 30 days) {
                activityComponent = 2000 - ((elapsed - 1 days) * 2000) / (29 days);
            }
            // else 0
        }

        // --- Stake component (20% weight = 2000 max) ---
        // Linear up to 1 ETH stake = full score
        uint256 stakeComponent;
        uint256 stakeWei = uint256(p.stake);
        if (stakeWei >= 1 ether) {
            stakeComponent = 2000;
        } else {
            stakeComponent = (stakeWei * 2000) / 1 ether;
        }

        score = successComponent + activityComponent + stakeComponent;
    }

    /// @notice Check if an executor is eligible to participate
    /// @param executor The address to check
    /// @return True if registered and staked above minimum
    function isEligible(address executor) external view returns (bool) {
        ExecutorProfile storage p = _profiles[executor];
        return p.registeredAt != 0 && p.stake >= MIN_STAKE;
    }

    /// @notice Get the full profile for an executor
    /// @param executor The executor address
    /// @return The executor's profile struct
    function getProfile(address executor) external view returns (ExecutorProfile memory) {
        return _profiles[executor];
    }
}
