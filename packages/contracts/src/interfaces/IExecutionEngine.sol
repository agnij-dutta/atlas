// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IExecutionEngine {
    event StepExecuted(uint256 indexed workflowId, uint256 indexed stepIndex, address indexed executor, uint256 gasUsed);
    event StepFailed(uint256 indexed workflowId, uint256 indexed stepIndex, bytes reason);

    function executeStep(uint256 workflowId) external;
    function isStepReady(uint256 workflowId) external view returns (bool);
}
