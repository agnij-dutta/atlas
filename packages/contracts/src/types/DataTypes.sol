// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library DataTypes {
    enum WorkflowStatus {
        NONE,
        ACTIVE,
        PAUSED,
        COMPLETED,
        FAILED
    }

    enum StepType {
        CONTRACT_CALL,
        TOKEN_TRANSFER,
        CONDITION_CHECK,
        DELAY
    }

    struct Workflow {
        uint256 id;
        address owner;
        WorkflowStatus status;
        uint256 currentStepIndex;
        uint256 totalSteps;
        uint256 rewardBalance;
        uint256 rewardPerStep;
        uint256 createdAt;
        uint256 lastExecutedAt;
    }

    struct Step {
        StepType stepType;
        address target;
        bytes callData;
        uint256 value;
        uint256 delay;
        bytes conditionData;
    }

    struct StepExecutionResult {
        bool success;
        bytes returnData;
        uint256 gasUsed;
    }
}
