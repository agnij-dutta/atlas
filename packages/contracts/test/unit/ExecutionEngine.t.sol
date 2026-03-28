// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestSetup} from "../helpers/TestSetup.sol";
import {DataTypes} from "../../src/types/DataTypes.sol";
import {ExecutionEngine} from "../../src/core/ExecutionEngine.sol";
import {AtlasAccessControl} from "../../src/access/AtlasAccessControl.sol";
import {IExecutionEngine} from "../../src/interfaces/IExecutionEngine.sol";

contract ExecutionEngineTest is TestSetup {
    // ==================== initialize ====================

    function test_initialize_setsRegistryAndRewardManager() public view {
        assertEq(address(engine.registry()), address(registry));
        assertEq(address(engine.rewardManager()), address(rewardManager));
    }

    function test_initialize_setsOwner() public view {
        assertEq(engine.owner(), owner);
    }

    // ==================== executeStep: CONTRACT_CALL ====================

    function test_executeStep_executesContractCall() public {
        uint256 wfId = _createSimpleWorkflow();

        // Fund the reward manager so it can pay the executor

        vm.prank(executor);
        engine.executeStep(wfId);

        // Verify the contract call executed
        assertEq(mockTarget.value(), 42);
    }

    function test_executeStep_paysRewardToExecutor() public {
        uint256 wfId = _createSimpleWorkflow();


        uint256 executorBalanceBefore = executor.balance;

        vm.prank(executor);
        engine.executeStep(wfId);

        assertEq(executor.balance, executorBalanceBefore + DEFAULT_REWARD);
    }

    function test_executeStep_advancesWorkflow() public {
        uint256 wfId = _createMultiStepWorkflow(2, DEFAULT_REWARD);


        vm.prank(executor);
        engine.executeStep(wfId);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(wf.currentStepIndex, 1);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.ACTIVE));
    }

    function test_executeStep_completesWorkflowOnLastStep() public {
        uint256 wfId = _createSimpleWorkflow();


        vm.prank(executor);
        engine.executeStep(wfId);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.COMPLETED));
    }

    function test_executeStep_revertsIfNotActive() public {
        uint256 wfId = _createSimpleWorkflow();

        // Pause it
        vm.prank(alice);
        registry.pauseWorkflow(wfId);

        vm.prank(executor);
        vm.expectRevert(ExecutionEngine.WorkflowNotActive.selector);
        engine.executeStep(wfId);
    }

    function test_executeStep_revertsIfNotExecutor() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(bob);
        vm.expectRevert(AtlasAccessControl.NotExecutor.selector);
        engine.executeStep(wfId);
    }

    function test_executeStep_emitsEvent() public {
        uint256 wfId = _createSimpleWorkflow();


        // We check topic1 (workflowId) and topic2 (stepIndex) and topic3 (executor)
        vm.expectEmit(true, true, true, false);
        emit IExecutionEngine.StepExecuted(wfId, 0, executor, 0);

        vm.prank(executor);
        engine.executeStep(wfId);
    }

    // ==================== executeStep: DELAY ====================

    function test_executeStep_delaySucceedsWhenNoLastExecution() public {
        // A workflow whose first step is a DELAY. Since lastExecutedAt == 0,
        // StepLib.isDelayMet returns true immediately.
        DataTypes.Step[] memory steps = new DataTypes.Step[](1);
        steps[0] = _buildDelayStep(1 hours);

        vm.prank(alice);
        uint256 wfId = registry.createWorkflow{value: DEFAULT_REWARD}(steps, DEFAULT_REWARD);


        vm.prank(executor);
        engine.executeStep(wfId);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.COMPLETED));
    }

    function test_executeStep_delayRevertsBeforeTimeElapsed() public {
        // Create 2-step workflow: CONTRACT_CALL then DELAY
        DataTypes.Step[] memory steps = new DataTypes.Step[](2);
        steps[0] = _buildContractCallStep(1);
        steps[1] = _buildDelayStep(1 hours);

        vm.prank(alice);
        uint256 wfId = registry.createWorkflow{value: DEFAULT_REWARD * 2}(steps, DEFAULT_REWARD);


        // Execute step 0
        vm.prank(executor);
        engine.executeStep(wfId);

        // Try step 1 immediately — should fail because delay not met
        vm.prank(executor);
        vm.expectRevert(ExecutionEngine.StepNotReady.selector);
        engine.executeStep(wfId);
    }

    function test_executeStep_delaySucceedsAfterTimeElapsed() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](2);
        steps[0] = _buildContractCallStep(1);
        steps[1] = _buildDelayStep(1 hours);

        vm.prank(alice);
        uint256 wfId = registry.createWorkflow{value: DEFAULT_REWARD * 2}(steps, DEFAULT_REWARD);


        // Execute step 0
        vm.prank(executor);
        engine.executeStep(wfId);

        // Warp forward past the delay
        vm.warp(block.timestamp + 1 hours + 1);

        // Now step 1 should succeed
        vm.prank(executor);
        engine.executeStep(wfId);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.COMPLETED));
    }

    // ==================== isStepReady ====================

    function test_isStepReady_returnsTrueForActiveWorkflow() public {
        uint256 wfId = _createSimpleWorkflow();
        assertTrue(engine.isStepReady(wfId));
    }

    function test_isStepReady_returnsFalseForPausedWorkflow() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(alice);
        registry.pauseWorkflow(wfId);

        assertFalse(engine.isStepReady(wfId));
    }

    function test_isStepReady_returnsFalseForCompletedWorkflow() public {
        uint256 wfId = _createSimpleWorkflow();


        vm.prank(executor);
        engine.executeStep(wfId);

        assertFalse(engine.isStepReady(wfId));
    }

    function test_isStepReady_returnsFalseWhenDelayNotMet() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](2);
        steps[0] = _buildContractCallStep(1);
        steps[1] = _buildDelayStep(1 hours);

        vm.prank(alice);
        uint256 wfId = registry.createWorkflow{value: DEFAULT_REWARD * 2}(steps, DEFAULT_REWARD);


        // Execute step 0
        vm.prank(executor);
        engine.executeStep(wfId);

        // Step 1 is DELAY and time has not passed
        assertFalse(engine.isStepReady(wfId));
    }

    function test_isStepReady_returnsTrueWhenDelayMet() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](2);
        steps[0] = _buildContractCallStep(1);
        steps[1] = _buildDelayStep(1 hours);

        vm.prank(alice);
        uint256 wfId = registry.createWorkflow{value: DEFAULT_REWARD * 2}(steps, DEFAULT_REWARD);


        vm.prank(executor);
        engine.executeStep(wfId);

        vm.warp(block.timestamp + 1 hours + 1);

        assertTrue(engine.isStepReady(wfId));
    }

    // ==================== executeStep: failed call ====================

    function test_executeStep_failedCallSetsWorkflowFailed() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](1);
        steps[0] = DataTypes.Step({
            stepType: DataTypes.StepType.CONTRACT_CALL,
            target: address(mockTarget),
            callData: abi.encodeCall(mockTarget.failAlways, ()),
            value: 0,
            delay: 0,
            conditionData: ""
        });

        vm.prank(alice);
        uint256 wfId = registry.createWorkflow{value: DEFAULT_REWARD}(steps, DEFAULT_REWARD);


        vm.prank(executor);
        engine.executeStep(wfId);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.FAILED));
    }
}
