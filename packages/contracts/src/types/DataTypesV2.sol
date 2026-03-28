// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title DataTypesV2
/// @notice Gas-optimized structs for future Atlas protocol migration.
///         NOT used by current contracts — provided as a migration reference.
/// @dev Storage layout is designed for minimal slot usage on the EVM.
///      Each struct documents its packing layout in comments.
library DataTypesV2 {
    /// @notice Optimized workflow struct — 3 storage slots vs 9 in DataTypes.Workflow
    /// @dev Slot 0: owner(20) + status(1) + currentStepIndex(2) + totalSteps(2) + createdAt(6) = 31 bytes
    ///      Slot 1: lastExecutedAt(6) + rewardBalance(16) + _pad(10) = 32 bytes
    ///      Slot 2: rewardPerStep(16) + id packed or stored separately
    ///      Note: id is typically the mapping key and does not need to be stored in the struct.
    struct WorkflowV2 {
        address owner;              // slot 0: 20 bytes
        uint8 status;               // slot 0:  1 byte  (5 enum values fit in uint8)
        uint16 currentStepIndex;    // slot 0:  2 bytes (max 65535 steps)
        uint16 totalSteps;          // slot 0:  2 bytes
        uint48 createdAt;           // slot 0:  6 bytes (good until year 8921556)
        uint48 lastExecutedAt;      // slot 1:  6 bytes
        uint128 rewardBalance;      // slot 1: 16 bytes (up to ~3.4e38 wei)
        uint128 rewardPerStep;      // slot 2: 16 bytes
    }

    /// @notice Optimized step struct for reduced calldata and storage costs
    /// @dev target and stepType pack into slot 0 (20 + 1 = 21 bytes).
    ///      value and delay pack into slot 1 (16 + 6 = 22 bytes).
    ///      Dynamic fields (callData, conditionData) are stored in separate slots
    ///      as per Solidity ABI encoding rules for dynamic types.
    struct StepV2 {
        address target;             // slot 0: 20 bytes
        uint8 stepType;             // slot 0:  1 byte
        uint128 value;              // slot 1: 16 bytes (sufficient for ETH transfers)
        uint48 delay;               // slot 1:  6 bytes (max ~8900 years)
        bytes callData;             // dynamic
        bytes conditionData;        // dynamic
    }

    /// @notice Optimized execution result — packed into a single slot + dynamic return data
    struct StepExecutionResultV2 {
        bool success;               // slot 0: 1 byte
        uint128 gasUsed;            // slot 0: 16 bytes
        bytes returnData;           // dynamic
    }
}
