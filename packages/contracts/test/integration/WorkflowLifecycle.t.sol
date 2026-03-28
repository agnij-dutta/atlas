// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestSetup} from "../helpers/TestSetup.sol";
import {DataTypes} from "../../src/types/DataTypes.sol";
import {MockTarget} from "../helpers/MockTarget.sol";

/// @title WorkflowLifecycleTest
/// @notice Full end-to-end lifecycle test: create workflow, execute all steps, verify final state
contract WorkflowLifecycleTest is TestSetup {
    MockTarget public target2;

    function setUp() public override {
        super.setUp();
        target2 = new MockTarget();
    }

    function test_fullLifecycle_threeStepWorkflow() public {
        // -------- Setup: Create a 3-step workflow --------
        // Step 0: CONTRACT_CALL — mockTarget.setValue(100)
        // Step 1: DELAY — 1 hour
        // Step 2: CONTRACT_CALL — target2.setValue(200)

        DataTypes.Step[] memory steps = new DataTypes.Step[](3);
        steps[0] = DataTypes.Step({
            stepType: DataTypes.StepType.CONTRACT_CALL,
            target: address(mockTarget),
            callData: abi.encodeCall(MockTarget.setValue, (100)),
            value: 0,
            delay: 0,
            conditionData: ""
        });
        steps[1] = DataTypes.Step({
            stepType: DataTypes.StepType.DELAY,
            target: address(0),
            callData: "",
            value: 0,
            delay: 1 hours,
            conditionData: ""
        });
        steps[2] = DataTypes.Step({
            stepType: DataTypes.StepType.CONTRACT_CALL,
            target: address(target2),
            callData: abi.encodeCall(MockTarget.setValue, (200)),
            value: 0,
            delay: 0,
            conditionData: ""
        });

        uint256 rewardPerStep = 0.01 ether;
        uint256 totalReward = rewardPerStep * 3;

        // Alice creates the workflow
        vm.prank(alice);
        uint256 wfId = registry.createWorkflow{value: totalReward}(steps, rewardPerStep);

        // Verify initial state
        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.ACTIVE));
        assertEq(wf.currentStepIndex, 0);
        assertEq(wf.totalSteps, 3);

        uint256 executorBalStart = executor.balance;

        // -------- Step 1: Execute CONTRACT_CALL --------
        assertTrue(engine.isStepReady(wfId));

        vm.prank(executor);
        engine.executeStep(wfId);

        assertEq(mockTarget.value(), 100);
        wf = registry.getWorkflow(wfId);
        assertEq(wf.currentStepIndex, 1);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.ACTIVE));
        assertEq(executor.balance, executorBalStart + rewardPerStep);

        // -------- Step 2: DELAY — must wait --------
        // isStepReady should be false immediately
        assertFalse(engine.isStepReady(wfId));

        // Warp forward past the delay
        vm.warp(block.timestamp + 1 hours + 1);

        assertTrue(engine.isStepReady(wfId));

        vm.prank(executor);
        engine.executeStep(wfId);

        wf = registry.getWorkflow(wfId);
        assertEq(wf.currentStepIndex, 2);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.ACTIVE));
        assertEq(executor.balance, executorBalStart + rewardPerStep * 2);

        // -------- Step 3: Execute CONTRACT_CALL — completes workflow --------
        assertTrue(engine.isStepReady(wfId));

        vm.prank(executor);
        engine.executeStep(wfId);

        assertEq(target2.value(), 200);
        wf = registry.getWorkflow(wfId);
        assertEq(wf.currentStepIndex, 3);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.COMPLETED));
        assertEq(executor.balance, executorBalStart + rewardPerStep * 3);

        // -------- Final verification --------
        // isStepReady should be false for completed workflow
        assertFalse(engine.isStepReady(wfId));

        // Registry reward balance for this workflow should be zero
        assertEq(registry.getWorkflow(wfId).rewardBalance, 0);
    }

    function test_lifecycle_pauseAndResumeMidWorkflow() public {
        uint256 wfId = _createMultiStepWorkflow(3, DEFAULT_REWARD);

        // Execute step 0
        vm.prank(executor);
        engine.executeStep(wfId);

        // Alice pauses
        vm.prank(alice);
        registry.pauseWorkflow(wfId);

        // Executor cannot execute while paused
        vm.prank(executor);
        vm.expectRevert();
        engine.executeStep(wfId);

        // Alice resumes
        vm.prank(alice);
        registry.resumeWorkflow(wfId);

        // Now executor can continue
        vm.prank(executor);
        engine.executeStep(wfId);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(wf.currentStepIndex, 2);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.ACTIVE));
    }

    function test_lifecycle_cancelMidWorkflow() public {
        uint256 wfId = _createMultiStepWorkflow(3, DEFAULT_REWARD);

        // Execute step 0
        vm.prank(executor);
        engine.executeStep(wfId);

        // Alice cancels — gets refund of remaining balance from registry
        uint256 aliceBalBefore = alice.balance;

        vm.prank(alice);
        registry.cancelWorkflow(wfId);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.FAILED));

        // Alice should have received the remaining balance held by the registry
        // (The registry held totalReward and deducted rewardPerStep for step 0)
        uint256 expectedRefund = DEFAULT_REWARD * 3 - DEFAULT_REWARD;
        assertEq(alice.balance, aliceBalBefore + expectedRefund);
    }
}
