// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestSetup} from "../helpers/TestSetup.sol";
import {RewardManager} from "../../src/core/RewardManager.sol";

contract RewardManagerFuzzTest is TestSetup {
    /// @notice Fuzz deposit amounts: balance always equals cumulative deposits
    function testFuzz_deposit_balanceAlwaysCorrect(uint96 amount1Raw, uint96 amount2Raw) public {
        uint256 amount1 = bound(uint256(amount1Raw), 1, 10 ether);
        uint256 amount2 = bound(uint256(amount2Raw), 1, 10 ether);

        uint256 workflowId = 42;

        rewardManager.deposit{value: amount1}(workflowId);
        assertEq(rewardManager.getBalance(workflowId), amount1);

        rewardManager.deposit{value: amount2}(workflowId);
        assertEq(rewardManager.getBalance(workflowId), amount1 + amount2);
    }

    /// @notice Fuzz multiple claims: cannot claim the same step twice
    function testFuzz_payReward_cannotOverclaim(uint8 stepIndexRaw, uint96 amountRaw) public {
        uint256 stepIndex = bound(uint256(stepIndexRaw), 0, 100);
        uint256 amount = bound(uint256(amountRaw), 1, 1 ether);

        uint256 workflowId = 1;

        // Deposit enough
        rewardManager.deposit{value: 10 ether}(workflowId);

        // First claim succeeds
        vm.prank(executor);
        rewardManager.payReward(workflowId, stepIndex, executor, amount);

        // Second claim for same step always reverts
        vm.prank(executor);
        vm.expectRevert(RewardManager.AlreadyClaimed.selector);
        rewardManager.payReward(workflowId, stepIndex, executor, amount);
    }

    /// @notice Fuzz: payReward never pays more than the balance
    function testFuzz_payReward_neverExceedsBalance(uint96 depositRaw, uint96 claimRaw) public {
        uint256 deposit = bound(uint256(depositRaw), 1, 10 ether);
        uint256 claim = bound(uint256(claimRaw), 1, 10 ether);

        uint256 workflowId = 1;

        rewardManager.deposit{value: deposit}(workflowId);

        if (claim > deposit) {
            vm.prank(executor);
            vm.expectRevert(RewardManager.InsufficientBalance.selector);
            rewardManager.payReward(workflowId, 0, executor, claim);
        } else {
            uint256 executorBalBefore = executor.balance;

            vm.prank(executor);
            rewardManager.payReward(workflowId, 0, executor, claim);

            assertEq(executor.balance, executorBalBefore + claim);
            assertEq(rewardManager.getBalance(workflowId), deposit - claim);
        }
    }
}
