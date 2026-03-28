// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "./DataTypes.sol";

/// @title CrossChainTypes
/// @notice Type definitions for cross-chain workflow execution in the Atlas protocol.
///         This is an interface-only module — provided for future implementation.
/// @dev These types extend the base DataTypes with cross-chain and DAG capabilities.
///      WorkflowDAG enables non-linear step execution via dependency graphs.
library CrossChainTypes {
    /// @notice A workflow step that targets execution on a different chain
    /// @dev bridgeData is an opaque payload specific to the bridge provider (e.g. Chainlink CCIP,
    ///      LayerZero, Hyperlane). The executor or relayer decodes it to route the message.
    struct CrossChainStep {
        uint256 targetChainId;
        DataTypes.StepType stepType;
        address target;
        bytes callData;
        uint256 value;
        uint256 delay;
        bytes conditionData;
        bytes bridgeData;
    }

    /// @notice A directed acyclic graph (DAG) of workflow steps
    /// @dev Enables parallel and conditional execution paths. A step can only execute
    ///      once ALL of its prerequisite steps (dependencies) have completed successfully.
    ///      Note: mappings cannot be part of memory structs — this type is storage-only.
    struct WorkflowDAG {
        uint256 id;
        uint256[] stepIds;
        // stepId => array of prerequisite stepIds that must complete before this step
        // Note: This field must be accessed in storage, not memory
        mapping(uint256 => uint256[]) dependencies;
    }

    /// @notice Metadata for a cross-chain message in transit
    /// @dev Used by bridge adapters to track message lifecycle
    struct CrossChainMessage {
        uint256 sourceChainId;
        uint256 targetChainId;
        uint256 workflowId;
        uint256 stepIndex;
        bytes32 messageId;
        uint64 sentAt;
        bool delivered;
    }
}
