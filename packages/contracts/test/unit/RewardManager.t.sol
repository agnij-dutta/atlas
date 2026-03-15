// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestSetup} from "../helpers/TestSetup.sol";
import {RewardManager} from "../../src/core/RewardManager.sol";
import {AtlasAccessControl} from "../../src/access/AtlasAccessControl.sol";
import {IRewardManager} from "../../src/interfaces/IRewardManager.sol";

contract RewardManagerTest is TestSetup {
    // ==================== deposit ====================

    function test_deposit_addsBalance() public {
        uint256 workflowId = 1;

        rewardManager.deposit{value: 1 ether}(workflowId);

        assertEq(rewardManager.getBalance(workflowId), 1 ether);
    }

    function test_deposit_emitsEvent() public {
        uint256 workflowId = 1;

        vm.expectEmit(true, false, false, true);
        emit IRewardManager.RewardDeposited(workflowId, 1 ether);

        rewardManager.deposit{value: 1 ether}(workflowId);
    }

    function test_deposit_revertsOnZero() public {
        vm.expectRevert(RewardManager.ZeroAmount.selector);
        rewardManager.deposit{value: 0}(1);
    }

    function test_deposit_accumulatesMultipleDeposits() public {
        uint256 workflowId = 1;

        rewardManager.deposit{value: 1 ether}(workflowId);
        rewardManager.deposit{value: 0.5 ether}(workflowId);

        assertEq(rewardManager.getBalance(workflowId), 1.5 ether);
    }

    // ==================== payReward ====================

    function test_payReward_paysExecutor() public {
        uint256 workflowId = 1;
        uint256 stepIndex = 0;
        uint256 amount = 0.1 ether;

        rewardManager.deposit{value: 1 ether}(workflowId);

        uint256 executorBalBefore = executor.balance;

        vm.prank(executor);
        rewardManager.payReward(workflowId, stepIndex, executor, amount);

        assertEq(executor.balance, executorBalBefore + amount);
    }

    function test_payReward_deductsBalance() public {
        uint256 workflowId = 1;

        rewardManager.deposit{value: 1 ether}(workflowId);

        vm.prank(executor);
        rewardManager.payReward(workflowId, 0, executor, 0.3 ether);

        assertEq(rewardManager.getBalance(workflowId), 0.7 ether);
    }

    function test_payReward_marksClaimed() public {
        uint256 workflowId = 1;

        rewardManager.deposit{value: 1 ether}(workflowId);

        vm.prank(executor);
        rewardManager.payReward(workflowId, 0, executor, 0.1 ether);

        // Second claim for same step should fail
        vm.prank(executor);
        vm.expectRevert(RewardManager.AlreadyClaimed.selector);
        rewardManager.payReward(workflowId, 0, executor, 0.1 ether);
    }

    function test_payReward_revertsIfAlreadyClaimed() public {
        uint256 workflowId = 1;

        rewardManager.deposit{value: 1 ether}(workflowId);

        vm.prank(executor);
        rewardManager.payReward(workflowId, 0, executor, 0.1 ether);

        vm.prank(executor);
        vm.expectRevert(RewardManager.AlreadyClaimed.selector);
        rewardManager.payReward(workflowId, 0, executor, 0.1 ether);
    }

    function test_payReward_revertsIfInsufficientBalance() public {
        uint256 workflowId = 1;

        rewardManager.deposit{value: 0.01 ether}(workflowId);

        vm.prank(executor);
        vm.expectRevert(RewardManager.InsufficientBalance.selector);
        rewardManager.payReward(workflowId, 0, executor, 1 ether);
    }

    function test_payReward_revertsIfNotExecutor() public {
        uint256 workflowId = 1;

        rewardManager.deposit{value: 1 ether}(workflowId);

        vm.prank(bob);
        vm.expectRevert(AtlasAccessControl.NotExecutor.selector);
        rewardManager.payReward(workflowId, 0, bob, 0.1 ether);
    }

    function test_payReward_emitsEvent() public {
        uint256 workflowId = 1;

        rewardManager.deposit{value: 1 ether}(workflowId);

        vm.expectEmit(true, true, true, true);
        emit IRewardManager.RewardClaimed(workflowId, 0, executor, 0.1 ether);

        vm.prank(executor);
        rewardManager.payReward(workflowId, 0, executor, 0.1 ether);
    }

    // ==================== refund ====================

    function test_refund_sendsBalanceToCaller() public {
        uint256 workflowId = 1;

        rewardManager.deposit{value: 1 ether}(workflowId);

        uint256 aliceBalBefore = alice.balance;

        vm.prank(alice);
        rewardManager.refund(workflowId);

        assertEq(alice.balance, aliceBalBefore + 1 ether);
        assertEq(rewardManager.getBalance(workflowId), 0);
    }

    function test_refund_emitsEvent() public {
        uint256 workflowId = 1;

        rewardManager.deposit{value: 1 ether}(workflowId);

        vm.expectEmit(true, true, false, true);
        emit IRewardManager.RewardRefunded(workflowId, alice, 1 ether);

        vm.prank(alice);
        rewardManager.refund(workflowId);
    }

    function test_refund_revertsIfZeroBalance() public {
        vm.prank(alice);
        vm.expectRevert(RewardManager.InsufficientBalance.selector);
        rewardManager.refund(1);
    }

    // ==================== getBalance ====================

    function test_getBalance_returnsCorrectBalance() public {
        uint256 workflowId = 1;

        assertEq(rewardManager.getBalance(workflowId), 0);

        rewardManager.deposit{value: 2 ether}(workflowId);
        assertEq(rewardManager.getBalance(workflowId), 2 ether);
    }
}
