// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../types/DataTypes.sol";

library WorkflowLib {
    error WorkflowNotActive();
    error WorkflowNotPaused();
    error NotWorkflowOwner();
    error WorkflowAlreadyCompleted();

    function validateActive(DataTypes.Workflow storage workflow) internal view {
        if (workflow.status != DataTypes.WorkflowStatus.ACTIVE) revert WorkflowNotActive();
    }

    function validatePaused(DataTypes.Workflow storage workflow) internal view {
        if (workflow.status != DataTypes.WorkflowStatus.PAUSED) revert WorkflowNotPaused();
    }

    function validateOwner(DataTypes.Workflow storage workflow, address caller) internal view {
        if (workflow.owner != caller) revert NotWorkflowOwner();
    }

    function isCompleted(DataTypes.Workflow storage workflow) internal view returns (bool) {
        return workflow.currentStepIndex >= workflow.totalSteps;
    }

    function advanceStep(DataTypes.Workflow storage workflow) internal {
        workflow.currentStepIndex++;
        workflow.lastExecutedAt = block.timestamp;
        if (workflow.currentStepIndex >= workflow.totalSteps) {
            workflow.status = DataTypes.WorkflowStatus.COMPLETED;
        }
    }
}
