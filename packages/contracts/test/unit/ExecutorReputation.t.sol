// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ExecutorReputation} from "../../src/core/ExecutorReputation.sol";
import {IExecutorReputation} from "../../src/interfaces/IExecutorReputation.sol";

/// @title ExecutorReputationTest
/// @notice Unit tests for the ExecutorReputation contract
contract ExecutorReputationTest is Test {
    ExecutorReputation public reputation;

    address public owner = makeAddr("owner");
    address public executor = makeAddr("executor");
    address public engineCaller = makeAddr("engineCaller");
    address public alice = makeAddr("alice");

    uint128 constant MIN_STAKE = 0.01 ether;
    uint64 constant WITHDRAWAL_DELAY = 7 days;

    function setUp() public {
        // Deploy behind UUPS proxy
        ExecutorReputation impl = new ExecutorReputation();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(ExecutorReputation.initialize, (owner))
        );
        reputation = ExecutorReputation(address(proxy));

        // Grant engine caller the executor role so it can call recordExecution/slash
        vm.prank(owner);
        reputation.addExecutor(engineCaller);

        // Fund accounts
        vm.deal(executor, 100 ether);
        vm.deal(alice, 100 ether);
    }

    // ==================== register ====================

    function test_register_succeeds() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        IExecutorReputation.ExecutorProfile memory p = reputation.getProfile(executor);
        assertEq(p.stake, MIN_STAKE);
        assertEq(p.registeredAt, uint64(block.timestamp));
        assertEq(p.lastActiveAt, uint64(block.timestamp));
    }

    function test_register_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit IExecutorReputation.ExecutorRegistered(executor, MIN_STAKE);

        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();
    }

    function test_register_withExtraStake() public {
        vm.prank(executor);
        reputation.register{value: 1 ether}();

        IExecutorReputation.ExecutorProfile memory p = reputation.getProfile(executor);
        assertEq(p.stake, 1 ether);
    }

    function test_register_revertsBelowMinStake() public {
        vm.prank(executor);
        vm.expectRevert(IExecutorReputation.BelowMinimumStake.selector);
        reputation.register{value: 0.001 ether}();
    }

    function test_register_revertsIfAlreadyRegistered() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        vm.prank(executor);
        vm.expectRevert(IExecutorReputation.AlreadyRegistered.selector);
        reputation.register{value: MIN_STAKE}();
    }

    // ==================== depositStake ====================

    function test_depositStake_addsToExisting() public {
        vm.startPrank(executor);
        reputation.register{value: MIN_STAKE}();
        reputation.depositStake{value: 0.5 ether}();
        vm.stopPrank();

        IExecutorReputation.ExecutorProfile memory p = reputation.getProfile(executor);
        assertEq(p.stake, MIN_STAKE + 0.5 ether);
    }

    function test_depositStake_emitsEvent() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        vm.expectEmit(true, false, false, true);
        emit IExecutorReputation.StakeDeposited(executor, 0.5 ether, uint128(MIN_STAKE + 0.5 ether));

        vm.prank(executor);
        reputation.depositStake{value: 0.5 ether}();
    }

    function test_depositStake_revertsIfNotRegistered() public {
        vm.prank(alice);
        vm.expectRevert(IExecutorReputation.NotRegistered.selector);
        reputation.depositStake{value: 1 ether}();
    }

    function test_depositStake_revertsOnZero() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        vm.prank(executor);
        vm.expectRevert(IExecutorReputation.ZeroAmount.selector);
        reputation.depositStake{value: 0}();
    }

    // ==================== requestWithdrawal ====================

    function test_requestWithdrawal_movesToPending() public {
        vm.prank(executor);
        reputation.register{value: 1 ether}();

        vm.prank(executor);
        reputation.requestWithdrawal(0.5 ether);

        IExecutorReputation.ExecutorProfile memory p = reputation.getProfile(executor);
        assertEq(p.stake, 0.5 ether);
        assertEq(p.pendingWithdrawal, 0.5 ether);
        assertEq(p.withdrawalUnlockTime, uint64(block.timestamp) + WITHDRAWAL_DELAY);
    }

    function test_requestWithdrawal_revertsIfExceedsStake() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        vm.prank(executor);
        vm.expectRevert(IExecutorReputation.InsufficientStake.selector);
        reputation.requestWithdrawal(1 ether);
    }

    function test_requestWithdrawal_revertsOnZero() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        vm.prank(executor);
        vm.expectRevert(IExecutorReputation.ZeroAmount.selector);
        reputation.requestWithdrawal(0);
    }

    // ==================== claimWithdrawal ====================

    function test_claimWithdrawal_afterDelay() public {
        vm.prank(executor);
        reputation.register{value: 1 ether}();

        vm.prank(executor);
        reputation.requestWithdrawal(0.5 ether);

        // Warp past delay
        vm.warp(block.timestamp + WITHDRAWAL_DELAY + 1);

        uint256 balBefore = executor.balance;

        vm.prank(executor);
        reputation.claimWithdrawal();

        assertEq(executor.balance, balBefore + 0.5 ether);

        IExecutorReputation.ExecutorProfile memory p = reputation.getProfile(executor);
        assertEq(p.pendingWithdrawal, 0);
        assertEq(p.withdrawalUnlockTime, 0);
    }

    function test_claimWithdrawal_revertsBeforeDelay() public {
        vm.prank(executor);
        reputation.register{value: 1 ether}();

        vm.prank(executor);
        reputation.requestWithdrawal(0.5 ether);

        vm.prank(executor);
        vm.expectRevert();
        reputation.claimWithdrawal();
    }

    function test_claimWithdrawal_revertsIfNoPending() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        vm.prank(executor);
        vm.expectRevert(IExecutorReputation.NoWithdrawalPending.selector);
        reputation.claimWithdrawal();
    }

    // ==================== recordExecution ====================

    function test_recordExecution_updatesSuccessMetrics() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        vm.prank(engineCaller);
        reputation.recordExecution(executor, 1, true, 50_000);

        IExecutorReputation.ExecutorProfile memory p = reputation.getProfile(executor);
        assertEq(p.totalExecutions, 1);
        assertEq(p.successfulExecutions, 1);
        assertEq(p.failedExecutions, 0);
        assertEq(p.cumulativeGasUsed, 50_000);
    }

    function test_recordExecution_updatesFailureMetrics() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        vm.prank(engineCaller);
        reputation.recordExecution(executor, 1, false, 30_000);

        IExecutorReputation.ExecutorProfile memory p = reputation.getProfile(executor);
        assertEq(p.totalExecutions, 1);
        assertEq(p.successfulExecutions, 0);
        assertEq(p.failedExecutions, 1);
    }

    function test_recordExecution_multipleExecutions() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        vm.startPrank(engineCaller);
        reputation.recordExecution(executor, 1, true, 50_000);
        reputation.recordExecution(executor, 2, true, 60_000);
        reputation.recordExecution(executor, 3, false, 40_000);
        vm.stopPrank();

        IExecutorReputation.ExecutorProfile memory p = reputation.getProfile(executor);
        assertEq(p.totalExecutions, 3);
        assertEq(p.successfulExecutions, 2);
        assertEq(p.failedExecutions, 1);
        assertEq(p.cumulativeGasUsed, 150_000);
    }

    function test_recordExecution_emitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IExecutorReputation.ExecutionRecorded(executor, 42, true, 50_000);

        vm.prank(engineCaller);
        reputation.recordExecution(executor, 42, true, 50_000);
    }

    function test_recordExecution_revertsIfNotExecutorRole() public {
        vm.prank(alice);
        vm.expectRevert();
        reputation.recordExecution(executor, 1, true, 50_000);
    }

    // ==================== slash ====================

    function test_slash_reducesStake() public {
        vm.prank(executor);
        reputation.register{value: 1 ether}();

        vm.prank(engineCaller);
        reputation.slash(executor, 0.5 ether, "missed_execution");

        IExecutorReputation.ExecutorProfile memory p = reputation.getProfile(executor);
        assertEq(p.stake, 0.5 ether);
    }

    function test_slash_byOwner() public {
        vm.prank(executor);
        reputation.register{value: 1 ether}();

        vm.prank(owner);
        reputation.slash(executor, 0.3 ether, "manual_slash");

        IExecutorReputation.ExecutorProfile memory p = reputation.getProfile(executor);
        assertEq(p.stake, 0.7 ether);
    }

    function test_slash_emitsEvent() public {
        vm.prank(executor);
        reputation.register{value: 1 ether}();

        vm.expectEmit(true, false, false, true);
        emit IExecutorReputation.ExecutorSlashed(executor, 0.5 ether, "test_reason");

        vm.prank(engineCaller);
        reputation.slash(executor, 0.5 ether, "test_reason");
    }

    function test_slash_revertsIfExceedsStake() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        vm.prank(engineCaller);
        vm.expectRevert(IExecutorReputation.SlashExceedsStake.selector);
        reputation.slash(executor, 1 ether, "too_much");
    }

    function test_slash_revertsIfUnauthorized() public {
        vm.prank(executor);
        reputation.register{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert();
        reputation.slash(executor, 0.1 ether, "unauthorized");
    }

    // ==================== isEligible ====================

    function test_isEligible_trueWhenStakedAboveMin() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        assertTrue(reputation.isEligible(executor));
    }

    function test_isEligible_falseWhenNotRegistered() public view {
        assertFalse(reputation.isEligible(alice));
    }

    function test_isEligible_falseWhenSlashedBelowMin() public {
        vm.prank(executor);
        reputation.register{value: MIN_STAKE}();

        // Slash below minimum
        vm.prank(engineCaller);
        reputation.slash(executor, MIN_STAKE, "full_slash");

        assertFalse(reputation.isEligible(executor));
    }

    // ==================== getReputationScore ====================

    function test_getReputationScore_zeroForUnregistered() public view {
        assertEq(reputation.getReputationScore(alice), 0);
    }

    function test_getReputationScore_maxForPerfectExecutor() public {
        vm.prank(executor);
        reputation.register{value: 1 ether}();

        // Record 10 successful executions
        vm.startPrank(engineCaller);
        for (uint256 i = 0; i < 10; i++) {
            reputation.recordExecution(executor, i, true, 50_000);
        }
        vm.stopPrank();

        // Perfect executor: 100% success (6000) + active now (2000) + 1 ETH stake (2000) = 10000
        uint256 score = reputation.getReputationScore(executor);
        assertEq(score, 10_000);
    }

    function test_getReputationScore_partialForMixedResults() public {
        vm.prank(executor);
        reputation.register{value: 0.5 ether}();

        // 7 successes, 3 failures = 70% success rate
        vm.startPrank(engineCaller);
        for (uint256 i = 0; i < 7; i++) {
            reputation.recordExecution(executor, i, true, 50_000);
        }
        for (uint256 i = 7; i < 10; i++) {
            reputation.recordExecution(executor, i, false, 50_000);
        }
        vm.stopPrank();

        uint256 score = reputation.getReputationScore(executor);

        // Success: (7/10) * 6000 = 4200
        // Activity: recent = 2000
        // Stake: 0.5 / 1.0 * 2000 = 1000
        // Total = 7200
        assertEq(score, 7200);
    }

    function test_getReputationScore_decaysWithInactivity() public {
        vm.prank(executor);
        reputation.register{value: 1 ether}();

        vm.prank(engineCaller);
        reputation.recordExecution(executor, 1, true, 50_000);

        // Warp forward 15 days (half of the 29-day decay window after the 1-day grace)
        vm.warp(block.timestamp + 15 days);

        uint256 score = reputation.getReputationScore(executor);

        // Success: (1/1) * 6000 = 6000
        // Activity: decayed from 2000 — 14 days into the 29-day window
        // activityComponent = 2000 - ((15 days - 1 days) * 2000) / 29 days = 2000 - (14*2000/29) ~ 2000 - 965 = 1034
        // Stake: 1 ETH = 2000
        // Total ~ 9034
        // Allow some rounding
        assertGt(score, 8900);
        assertLt(score, 9200);
    }

    function test_getReputationScore_zeroActivityAfter30Days() public {
        vm.prank(executor);
        reputation.register{value: 1 ether}();

        vm.prank(engineCaller);
        reputation.recordExecution(executor, 1, true, 50_000);

        // Warp forward 31 days
        vm.warp(block.timestamp + 31 days);

        uint256 score = reputation.getReputationScore(executor);

        // Success: 6000, Activity: 0, Stake: 2000 => 8000
        assertEq(score, 8000);
    }

    // ==================== getProfile ====================

    function test_getProfile_returnsEmptyForUnregistered() public view {
        IExecutorReputation.ExecutorProfile memory p = reputation.getProfile(alice);
        assertEq(p.stake, 0);
        assertEq(p.registeredAt, 0);
    }
}
