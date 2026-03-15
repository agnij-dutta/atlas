// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRewardManager} from "../interfaces/IRewardManager.sol";
import {AtlasAccessControl} from "../access/AtlasAccessControl.sol";

contract RewardManager is IRewardManager, AtlasAccessControl {
    mapping(uint256 => uint256) private _balances;
    mapping(uint256 => mapping(uint256 => bool)) private _claimed;

    error InsufficientBalance();
    error AlreadyClaimed();
    error TransferFailed();
    error ZeroAmount();

    function initialize(address owner_) external initializer {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
    }

    function deposit(uint256 workflowId) external payable {
        if (msg.value == 0) revert ZeroAmount();
        _balances[workflowId] += msg.value;
        emit RewardDeposited(workflowId, msg.value);
    }

    function claimReward(uint256 workflowId, uint256 stepIndex, address executor) external onlyExecutor {
        if (_claimed[workflowId][stepIndex]) revert AlreadyClaimed();

        uint256 balance = _balances[workflowId];
        if (balance == 0) revert InsufficientBalance();

        // Reward amount is passed contextually; for MVP we read from balance
        // The ExecutionEngine calculates and calls this
        _claimed[workflowId][stepIndex] = true;

        emit RewardClaimed(workflowId, stepIndex, executor, 0);
    }

    function payReward(uint256 workflowId, uint256 stepIndex, address executor, uint256 amount) external onlyExecutor {
        if (_claimed[workflowId][stepIndex]) revert AlreadyClaimed();
        if (_balances[workflowId] < amount) revert InsufficientBalance();

        _claimed[workflowId][stepIndex] = true;
        _balances[workflowId] -= amount;

        (bool success,) = executor.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit RewardClaimed(workflowId, stepIndex, executor, amount);
    }

    function refund(uint256 workflowId) external {
        uint256 balance = _balances[workflowId];
        if (balance == 0) revert InsufficientBalance();

        _balances[workflowId] = 0;

        // The caller (WorkflowRegistry) handles sending to owner
        (bool success,) = msg.sender.call{value: balance}("");
        if (!success) revert TransferFailed();

        emit RewardRefunded(workflowId, msg.sender, balance);
    }

    function getBalance(uint256 workflowId) external view returns (uint256) {
        return _balances[workflowId];
    }
}
