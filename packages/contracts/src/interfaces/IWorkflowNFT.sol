// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../types/DataTypes.sol";

/// @title IWorkflowNFT
/// @notice Interface for the WorkflowNFT contract that wraps workflows as ERC-721 tokens
interface IWorkflowNFT {
    /// @notice Emitted when a new workflow NFT is minted
    event WorkflowMinted(uint256 indexed tokenId, address indexed owner);

    /// @notice Creates a workflow via the registry and mints an NFT representing ownership
    /// @param steps The workflow steps to execute
    /// @param rewardPerStep The reward paid to executors per step
    /// @return tokenId The token ID (equal to the workflow ID in the registry)
    function createWorkflow(
        DataTypes.Step[] calldata steps,
        uint256 rewardPerStep
    ) external payable returns (uint256 tokenId);

    /// @notice Returns the workflow ID associated with a given token ID
    /// @param tokenId The NFT token ID
    /// @return The workflow ID (always equal to tokenId)
    function workflowIdOf(uint256 tokenId) external pure returns (uint256);
}
