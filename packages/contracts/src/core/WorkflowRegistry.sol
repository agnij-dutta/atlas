// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../types/DataTypes.sol";
import {IWorkflowRegistry} from "../interfaces/IWorkflowRegistry.sol";
import {WorkflowLib} from "../libraries/WorkflowLib.sol";
import {StepLib} from "../libraries/StepLib.sol";
import {AtlasAccessControl} from "../access/AtlasAccessControl.sol";

contract WorkflowRegistry is IWorkflowRegistry, AtlasAccessControl {
    using WorkflowLib for DataTypes.Workflow;

    uint256 private _nextWorkflowId;
    mapping(uint256 => DataTypes.Workflow) private _workflows;
    mapping(uint256 => DataTypes.Step[]) private _steps;

    /// @notice The WorkflowNFT contract authorized to create workflows on behalf of users
    address public workflowNFT;

    error NoSteps();
    error TooManySteps();
    error InvalidReward();
    error InsufficientDeposit();
    error RefundFailed();
    error NotWorkflowNFT();
    error WorkflowNFTAlreadySet();

    uint256 public constant MAX_STEPS = 50;
    uint256 public constant MIN_REWARD_PER_STEP = 0.0001 ether;

    modifier onlyWorkflowNFT() {
        if (msg.sender != workflowNFT) revert NotWorkflowNFT();
        _;
    }

    function initialize(address owner_) external initializer {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        _nextWorkflowId = 1;
    }

    function createWorkflow(
        DataTypes.Step[] calldata steps,
        uint256 rewardPerStep
    ) external payable returns (uint256) {
        if (steps.length == 0) revert NoSteps();
        if (steps.length > MAX_STEPS) revert TooManySteps();
        if (rewardPerStep < MIN_REWARD_PER_STEP) revert InvalidReward();

        uint256 totalReward = rewardPerStep * steps.length;
        if (msg.value < totalReward) revert InsufficientDeposit();

        uint256 workflowId = _nextWorkflowId++;

        DataTypes.Workflow storage wf = _workflows[workflowId];
        wf.id = workflowId;
        wf.owner = msg.sender;
        wf.status = DataTypes.WorkflowStatus.ACTIVE;
        wf.currentStepIndex = 0;
        wf.totalSteps = steps.length;
        wf.rewardBalance = msg.value;
        wf.rewardPerStep = rewardPerStep;
        wf.createdAt = block.timestamp;

        for (uint256 i = 0; i < steps.length; i++) {
            StepLib.validate(steps[i]);
            _steps[workflowId].push(steps[i]);
        }

        emit WorkflowCreated(workflowId, msg.sender, steps.length, rewardPerStep);
        return workflowId;
    }

    /// @notice Creates a workflow on behalf of another address
    /// @dev Only callable by the authorized WorkflowNFT contract
    /// @param workflowOwner The address that will own the workflow
    /// @param steps The workflow steps
    /// @param rewardPerStep The reward per step for executors
    /// @return The new workflow ID
    function createWorkflowFor(
        address workflowOwner,
        DataTypes.Step[] calldata steps,
        uint256 rewardPerStep
    ) external payable onlyWorkflowNFT returns (uint256) {
        if (steps.length == 0) revert NoSteps();
        if (steps.length > MAX_STEPS) revert TooManySteps();
        if (rewardPerStep < MIN_REWARD_PER_STEP) revert InvalidReward();

        uint256 totalReward = rewardPerStep * steps.length;
        if (msg.value < totalReward) revert InsufficientDeposit();

        uint256 workflowId = _nextWorkflowId++;

        DataTypes.Workflow storage wf = _workflows[workflowId];
        wf.id = workflowId;
        wf.owner = workflowOwner;
        wf.status = DataTypes.WorkflowStatus.ACTIVE;
        wf.currentStepIndex = 0;
        wf.totalSteps = steps.length;
        wf.rewardBalance = msg.value;
        wf.rewardPerStep = rewardPerStep;
        wf.createdAt = block.timestamp;

        for (uint256 i = 0; i < steps.length; i++) {
            StepLib.validate(steps[i]);
            _steps[workflowId].push(steps[i]);
        }

        emit WorkflowCreated(workflowId, workflowOwner, steps.length, rewardPerStep);
        return workflowId;
    }

    /// @notice Sets the workflow NFT contract address (one-time setup)
    /// @param nftAddress The WorkflowNFT contract address
    function setWorkflowNFTAddress(address nftAddress) external onlyOwner {
        if (workflowNFT != address(0)) revert WorkflowNFTAlreadySet();
        if (nftAddress == address(0)) revert ZeroAddress();
        workflowNFT = nftAddress;
    }

    /// @notice Updates workflow ownership — only callable by the WorkflowNFT contract
    /// @param workflowId The workflow to transfer
    /// @param newOwner The new owner address
    function setWorkflowOwner(uint256 workflowId, address newOwner) external onlyWorkflowNFT {
        _workflows[workflowId].owner = newOwner;
        emit WorkflowOwnerChanged(workflowId, newOwner);
    }

    function pauseWorkflow(uint256 workflowId) external {
        DataTypes.Workflow storage wf = _workflows[workflowId];
        wf.validateOwner(msg.sender);
        wf.validateActive();
        wf.status = DataTypes.WorkflowStatus.PAUSED;
        emit WorkflowPaused(workflowId);
    }

    function resumeWorkflow(uint256 workflowId) external {
        DataTypes.Workflow storage wf = _workflows[workflowId];
        wf.validateOwner(msg.sender);
        wf.validatePaused();
        wf.status = DataTypes.WorkflowStatus.ACTIVE;
        emit WorkflowResumed(workflowId);
    }

    function cancelWorkflow(uint256 workflowId) external {
        DataTypes.Workflow storage wf = _workflows[workflowId];
        wf.validateOwner(msg.sender);
        if (wf.status == DataTypes.WorkflowStatus.COMPLETED) revert WorkflowLib.WorkflowAlreadyCompleted();

        uint256 refundAmount = wf.rewardBalance;
        wf.status = DataTypes.WorkflowStatus.FAILED;
        wf.rewardBalance = 0;

        if (refundAmount > 0) {
            (bool success,) = msg.sender.call{value: refundAmount}("");
            if (!success) revert RefundFailed();
        }

        emit WorkflowCancelled(workflowId, refundAmount);
    }

    // --- State mutation by ExecutionEngine ---

    function advanceWorkflow(uint256 workflowId) external onlyExecutor {
        DataTypes.Workflow storage wf = _workflows[workflowId];
        wf.advanceStep();
        if (wf.status == DataTypes.WorkflowStatus.COMPLETED) {
            emit WorkflowCompleted(workflowId);
        }
    }

    function failWorkflow(uint256 workflowId, uint256 stepIndex) external onlyExecutor {
        DataTypes.Workflow storage wf = _workflows[workflowId];
        wf.status = DataTypes.WorkflowStatus.FAILED;
        emit WorkflowFailed(workflowId, stepIndex);
    }

    function deductReward(uint256 workflowId, uint256 amount) external onlyExecutor {
        _workflows[workflowId].rewardBalance -= amount;
    }

    function payExecutor(uint256 workflowId, uint256 amount, address executor) external onlyExecutor {
        _workflows[workflowId].rewardBalance -= amount;
        (bool success,) = executor.call{value: amount}("");
        if (!success) revert RefundFailed();
    }

    // --- View functions ---

    function getWorkflow(uint256 workflowId) external view returns (DataTypes.Workflow memory) {
        return _workflows[workflowId];
    }

    function getSteps(uint256 workflowId) external view returns (DataTypes.Step[] memory) {
        return _steps[workflowId];
    }

    function getStep(uint256 workflowId, uint256 stepIndex) external view returns (DataTypes.Step memory) {
        return _steps[workflowId][stepIndex];
    }

    function workflowCount() external view returns (uint256) {
        return _nextWorkflowId - 1;
    }
}
