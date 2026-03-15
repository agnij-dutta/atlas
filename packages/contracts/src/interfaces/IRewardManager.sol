// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRewardManager {
    event RewardDeposited(uint256 indexed workflowId, uint256 amount);
    event RewardClaimed(uint256 indexed workflowId, uint256 indexed stepIndex, address indexed executor, uint256 amount);
    event RewardRefunded(uint256 indexed workflowId, address indexed owner, uint256 amount);

    function deposit(uint256 workflowId) external payable;
    function claimReward(uint256 workflowId, uint256 stepIndex, address executor) external;
    function refund(uint256 workflowId) external;
    function getBalance(uint256 workflowId) external view returns (uint256);
}
