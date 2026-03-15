// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../types/DataTypes.sol";

interface IWorkflowRegistry {
    event WorkflowCreated(uint256 indexed workflowId, address indexed owner, uint256 totalSteps, uint256 rewardPerStep);
    event WorkflowPaused(uint256 indexed workflowId);
    event WorkflowResumed(uint256 indexed workflowId);
    event WorkflowCancelled(uint256 indexed workflowId, uint256 refundAmount);
    event WorkflowCompleted(uint256 indexed workflowId);
    event WorkflowFailed(uint256 indexed workflowId, uint256 stepIndex);

    function createWorkflow(DataTypes.Step[] calldata steps, uint256 rewardPerStep) external payable returns (uint256);
    function pauseWorkflow(uint256 workflowId) external;
    function resumeWorkflow(uint256 workflowId) external;
    function cancelWorkflow(uint256 workflowId) external;

    function getWorkflow(uint256 workflowId) external view returns (DataTypes.Workflow memory);
    function getSteps(uint256 workflowId) external view returns (DataTypes.Step[] memory);
    function getStep(uint256 workflowId, uint256 stepIndex) external view returns (DataTypes.Step memory);
    function workflowCount() external view returns (uint256);
}
