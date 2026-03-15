// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../types/DataTypes.sol";

library StepLib {
    error InvalidStep();
    error StepDelayNotMet();
    error InvalidTarget();

    function validate(DataTypes.Step memory step) internal pure {
        if (step.stepType == DataTypes.StepType.CONTRACT_CALL || step.stepType == DataTypes.StepType.TOKEN_TRANSFER) {
            if (step.target == address(0)) revert InvalidTarget();
        }
    }

    function isDelayMet(DataTypes.Step memory step, uint256 lastExecutedAt) internal view returns (bool) {
        if (step.stepType != DataTypes.StepType.DELAY) return true;
        if (lastExecutedAt == 0) return true;
        return block.timestamp >= lastExecutedAt + step.delay;
    }
}
