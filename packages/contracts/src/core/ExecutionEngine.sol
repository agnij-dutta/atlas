// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../types/DataTypes.sol";
import {IExecutionEngine} from "../interfaces/IExecutionEngine.sol";
import {StepLib} from "../libraries/StepLib.sol";
import {StepExecutors} from "./StepExecutors.sol";
import {WorkflowRegistry} from "./WorkflowRegistry.sol";
import {RewardManager} from "./RewardManager.sol";
import {AtlasAccessControl} from "../access/AtlasAccessControl.sol";

contract ExecutionEngine is IExecutionEngine, AtlasAccessControl {
    WorkflowRegistry public registry;
    RewardManager public rewardManager;

    error StepNotReady();
    error WorkflowNotActive();

    function initialize(
        address owner_,
        address registry_,
        address rewardManager_
    ) external initializer {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        registry = WorkflowRegistry(registry_);
        rewardManager = RewardManager(payable(rewardManager_));
    }

    function executeStep(uint256 workflowId) external onlyExecutor {
        DataTypes.Workflow memory wf = registry.getWorkflow(workflowId);
        if (wf.status != DataTypes.WorkflowStatus.ACTIVE) revert WorkflowNotActive();

        DataTypes.Step memory step = registry.getStep(workflowId, wf.currentStepIndex);

        // Validate delay condition
        if (!StepLib.isDelayMet(step, wf.lastExecutedAt)) revert StepNotReady();

        // Execute the step
        DataTypes.StepExecutionResult memory result = StepExecutors.execute(step);

        if (result.success) {
            // Advance workflow state
            registry.advanceWorkflow(workflowId);

            // Pay executor reward
            rewardManager.payReward(workflowId, wf.currentStepIndex, msg.sender, wf.rewardPerStep);
            registry.deductReward(workflowId, wf.rewardPerStep);

            emit StepExecuted(workflowId, wf.currentStepIndex, msg.sender, result.gasUsed);
        } else {
            registry.failWorkflow(workflowId, wf.currentStepIndex);
            emit StepFailed(workflowId, wf.currentStepIndex, result.returnData);
        }
    }

    function isStepReady(uint256 workflowId) external view returns (bool) {
        DataTypes.Workflow memory wf = registry.getWorkflow(workflowId);
        if (wf.status != DataTypes.WorkflowStatus.ACTIVE) return false;
        if (wf.currentStepIndex >= wf.totalSteps) return false;

        DataTypes.Step memory step = registry.getStep(workflowId, wf.currentStepIndex);
        return StepLib.isDelayMet(step, wf.lastExecutedAt);
    }
}
