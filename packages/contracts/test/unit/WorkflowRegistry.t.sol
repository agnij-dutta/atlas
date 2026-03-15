// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestSetup} from "../helpers/TestSetup.sol";
import {DataTypes} from "../../src/types/DataTypes.sol";
import {WorkflowLib} from "../../src/libraries/WorkflowLib.sol";
import {StepLib} from "../../src/libraries/StepLib.sol";
import {WorkflowRegistry} from "../../src/core/WorkflowRegistry.sol";
import {AtlasAccessControl} from "../../src/access/AtlasAccessControl.sol";
import {IWorkflowRegistry} from "../../src/interfaces/IWorkflowRegistry.sol";

contract WorkflowRegistryTest is TestSetup {
    // ==================== initialize ====================

    function test_initialize_setsOwner() public view {
        assertEq(registry.owner(), owner);
    }

    function test_initialize_nextWorkflowIdStartsAt1() public view {
        assertEq(registry.workflowCount(), 0);
    }

    // ==================== createWorkflow ====================

    function test_createWorkflow_createsWithCorrectState() public {
        uint256 wfId = _createSimpleWorkflow();

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(wf.id, 1);
        assertEq(wf.owner, alice);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.ACTIVE));
        assertEq(wf.currentStepIndex, 0);
        assertEq(wf.totalSteps, 1);
        assertEq(wf.rewardBalance, DEFAULT_REWARD);
        assertEq(wf.rewardPerStep, DEFAULT_REWARD);
        assertEq(wf.createdAt, block.timestamp);
    }

    function test_createWorkflow_emitsEvent() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](1);
        steps[0] = _buildContractCallStep(42);

        vm.expectEmit(true, true, false, true);
        emit IWorkflowRegistry.WorkflowCreated(1, alice, 1, DEFAULT_REWARD);

        vm.prank(alice);
        registry.createWorkflow{value: DEFAULT_REWARD}(steps, DEFAULT_REWARD);
    }

    function test_createWorkflow_requiresMinReward() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](1);
        steps[0] = _buildContractCallStep(42);

        uint256 tooLow = registry.MIN_REWARD_PER_STEP() - 1;

        vm.prank(alice);
        vm.expectRevert(WorkflowRegistry.InvalidReward.selector);
        registry.createWorkflow{value: tooLow}(steps, tooLow);
    }

    function test_createWorkflow_requiresDeposit() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](2);
        steps[0] = _buildContractCallStep(1);
        steps[1] = _buildContractCallStep(2);

        // Send enough for 1 step, but 2 steps required
        vm.prank(alice);
        vm.expectRevert(WorkflowRegistry.InsufficientDeposit.selector);
        registry.createWorkflow{value: DEFAULT_REWARD}(steps, DEFAULT_REWARD);
    }

    function test_createWorkflow_rejectsEmptySteps() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](0);

        vm.prank(alice);
        vm.expectRevert(WorkflowRegistry.NoSteps.selector);
        registry.createWorkflow{value: 0}(steps, DEFAULT_REWARD);
    }

    function test_createWorkflow_rejectsTooManySteps() public {
        uint256 maxSteps = registry.MAX_STEPS();
        DataTypes.Step[] memory steps = new DataTypes.Step[](maxSteps + 1);
        for (uint256 i = 0; i <= maxSteps; i++) {
            steps[i] = _buildContractCallStep(i);
        }

        uint256 totalReward = DEFAULT_REWARD * (maxSteps + 1);
        vm.prank(alice);
        vm.expectRevert(WorkflowRegistry.TooManySteps.selector);
        registry.createWorkflow{value: totalReward}(steps, DEFAULT_REWARD);
    }

    function test_createWorkflow_rejectsZeroTargetForContractCall() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](1);
        steps[0] = DataTypes.Step({
            stepType: DataTypes.StepType.CONTRACT_CALL,
            target: address(0),
            callData: "",
            value: 0,
            delay: 0,
            conditionData: ""
        });

        vm.prank(alice);
        vm.expectRevert(StepLib.InvalidTarget.selector);
        registry.createWorkflow{value: DEFAULT_REWARD}(steps, DEFAULT_REWARD);
    }

    function test_createWorkflow_incrementsWorkflowId() public {
        uint256 first = _createSimpleWorkflow();
        assertEq(first, 1);

        // Create a second workflow
        DataTypes.Step[] memory steps = new DataTypes.Step[](1);
        steps[0] = _buildContractCallStep(99);
        vm.prank(alice);
        uint256 second = registry.createWorkflow{value: DEFAULT_REWARD}(steps, DEFAULT_REWARD);
        assertEq(second, 2);

        assertEq(registry.workflowCount(), 2);
    }

    // ==================== pauseWorkflow ====================

    function test_pauseWorkflow_setsStatusPaused() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(alice);
        registry.pauseWorkflow(wfId);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.PAUSED));
    }

    function test_pauseWorkflow_emitsEvent() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.expectEmit(true, false, false, false);
        emit IWorkflowRegistry.WorkflowPaused(wfId);

        vm.prank(alice);
        registry.pauseWorkflow(wfId);
    }

    function test_pauseWorkflow_revertsIfNotOwner() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(bob);
        vm.expectRevert(WorkflowLib.NotWorkflowOwner.selector);
        registry.pauseWorkflow(wfId);
    }

    function test_pauseWorkflow_revertsIfNotActive() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(alice);
        registry.pauseWorkflow(wfId);

        // Already paused, try again
        vm.prank(alice);
        vm.expectRevert(WorkflowLib.WorkflowNotActive.selector);
        registry.pauseWorkflow(wfId);
    }

    // ==================== resumeWorkflow ====================

    function test_resumeWorkflow_setsStatusActive() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(alice);
        registry.pauseWorkflow(wfId);

        vm.prank(alice);
        registry.resumeWorkflow(wfId);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.ACTIVE));
    }

    function test_resumeWorkflow_emitsEvent() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(alice);
        registry.pauseWorkflow(wfId);

        vm.expectEmit(true, false, false, false);
        emit IWorkflowRegistry.WorkflowResumed(wfId);

        vm.prank(alice);
        registry.resumeWorkflow(wfId);
    }

    function test_resumeWorkflow_revertsIfNotOwner() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(alice);
        registry.pauseWorkflow(wfId);

        vm.prank(bob);
        vm.expectRevert(WorkflowLib.NotWorkflowOwner.selector);
        registry.resumeWorkflow(wfId);
    }

    function test_resumeWorkflow_revertsIfNotPaused() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(alice);
        vm.expectRevert(WorkflowLib.WorkflowNotPaused.selector);
        registry.resumeWorkflow(wfId);
    }

    // ==================== cancelWorkflow ====================

    function test_cancelWorkflow_refundsBalance() public {
        uint256 wfId = _createSimpleWorkflow();

        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        registry.cancelWorkflow(wfId);

        assertEq(alice.balance, balanceBefore + DEFAULT_REWARD);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(wf.rewardBalance, 0);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.FAILED));
    }

    function test_cancelWorkflow_emitsEvent() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.expectEmit(true, false, false, true);
        emit IWorkflowRegistry.WorkflowCancelled(wfId, DEFAULT_REWARD);

        vm.prank(alice);
        registry.cancelWorkflow(wfId);
    }

    function test_cancelWorkflow_revertsIfCompleted() public {
        uint256 wfId = _createSimpleWorkflow();

        // Advance to completed via executor
        vm.prank(executor);
        registry.advanceWorkflow(wfId);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.COMPLETED));

        vm.prank(alice);
        vm.expectRevert(WorkflowLib.WorkflowAlreadyCompleted.selector);
        registry.cancelWorkflow(wfId);
    }

    function test_cancelWorkflow_revertsIfNotOwner() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(bob);
        vm.expectRevert(WorkflowLib.NotWorkflowOwner.selector);
        registry.cancelWorkflow(wfId);
    }

    // ==================== View functions ====================

    function test_getWorkflow_returnsCorrectData() public {
        uint256 wfId = _createSimpleWorkflow();

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(wf.id, wfId);
        assertEq(wf.owner, alice);
        assertEq(wf.totalSteps, 1);
    }

    function test_getSteps_returnsAllSteps() public {
        uint256 wfId = _createMultiStepWorkflow(3, DEFAULT_REWARD);

        DataTypes.Step[] memory steps = registry.getSteps(wfId);
        assertEq(steps.length, 3);

        for (uint256 i = 0; i < 3; i++) {
            assertEq(uint8(steps[i].stepType), uint8(DataTypes.StepType.CONTRACT_CALL));
            assertEq(steps[i].target, address(mockTarget));
        }
    }

    function test_getStep_returnsSingleStep() public {
        uint256 wfId = _createMultiStepWorkflow(3, DEFAULT_REWARD);

        DataTypes.Step memory step = registry.getStep(wfId, 1);
        assertEq(uint8(step.stepType), uint8(DataTypes.StepType.CONTRACT_CALL));
        assertEq(step.target, address(mockTarget));
    }

    function test_workflowCount_returnsCorrectCount() public {
        assertEq(registry.workflowCount(), 0);

        _createSimpleWorkflow();
        assertEq(registry.workflowCount(), 1);

        _createSimpleWorkflow();
        assertEq(registry.workflowCount(), 2);
    }

    // ==================== advanceWorkflow ====================

    function test_advanceWorkflow_incrementsStep() public {
        uint256 wfId = _createMultiStepWorkflow(3, DEFAULT_REWARD);

        vm.prank(executor);
        registry.advanceWorkflow(wfId);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(wf.currentStepIndex, 1);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.ACTIVE));
    }

    function test_advanceWorkflow_setsCompletedWhenDone() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(executor);
        registry.advanceWorkflow(wfId);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.COMPLETED));
    }

    function test_advanceWorkflow_revertsIfNotExecutor() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(bob);
        vm.expectRevert(AtlasAccessControl.NotExecutor.selector);
        registry.advanceWorkflow(wfId);
    }

    // ==================== failWorkflow ====================

    function test_failWorkflow_setsStatusFailed() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(executor);
        registry.failWorkflow(wfId, 0);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.FAILED));
    }

    function test_failWorkflow_emitsEvent() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.expectEmit(true, true, false, false);
        emit IWorkflowRegistry.WorkflowFailed(wfId, 0);

        vm.prank(executor);
        registry.failWorkflow(wfId, 0);
    }

    function test_failWorkflow_revertsIfNotExecutor() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.prank(bob);
        vm.expectRevert(AtlasAccessControl.NotExecutor.selector);
        registry.failWorkflow(wfId, 0);
    }
}
