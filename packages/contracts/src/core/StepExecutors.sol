// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../types/DataTypes.sol";

library StepExecutors {
    error CallFailed(bytes reason);
    error TransferFailed();
    error UnsupportedStepType();

    function execute(DataTypes.Step memory step) internal returns (DataTypes.StepExecutionResult memory) {
        if (step.stepType == DataTypes.StepType.CONTRACT_CALL) {
            return _executeContractCall(step);
        } else if (step.stepType == DataTypes.StepType.TOKEN_TRANSFER) {
            return _executeTokenTransfer(step);
        } else if (step.stepType == DataTypes.StepType.DELAY) {
            // Delay steps are no-ops at execution; validation happens before
            return DataTypes.StepExecutionResult({success: true, returnData: "", gasUsed: 0});
        } else if (step.stepType == DataTypes.StepType.CONDITION_CHECK) {
            return _executeConditionCheck(step);
        }
        revert UnsupportedStepType();
    }

    function _executeContractCall(DataTypes.Step memory step) private returns (DataTypes.StepExecutionResult memory) {
        uint256 gasBefore = gasleft();
        (bool success, bytes memory returnData) = step.target.call{value: step.value}(step.callData);
        uint256 gasUsed = gasBefore - gasleft();

        if (!success) {
            return DataTypes.StepExecutionResult({success: false, returnData: returnData, gasUsed: gasUsed});
        }

        return DataTypes.StepExecutionResult({success: true, returnData: returnData, gasUsed: gasUsed});
    }

    function _executeTokenTransfer(DataTypes.Step memory step) private returns (DataTypes.StepExecutionResult memory) {
        uint256 gasBefore = gasleft();
        (bool success,) = step.target.call{value: step.value}("");
        uint256 gasUsed = gasBefore - gasleft();

        if (!success) {
            return DataTypes.StepExecutionResult({success: false, returnData: "", gasUsed: gasUsed});
        }

        return DataTypes.StepExecutionResult({success: true, returnData: "", gasUsed: gasUsed});
    }

    function _executeConditionCheck(DataTypes.Step memory step) private view returns (DataTypes.StepExecutionResult memory) {
        uint256 gasBefore = gasleft();
        (bool success, bytes memory returnData) = step.target.staticcall(step.conditionData);
        uint256 gasUsed = gasBefore - gasleft();

        if (!success) {
            return DataTypes.StepExecutionResult({success: false, returnData: returnData, gasUsed: gasUsed});
        }

        // Decode the bool result
        bool conditionMet = abi.decode(returnData, (bool));
        return DataTypes.StepExecutionResult({success: conditionMet, returnData: returnData, gasUsed: gasUsed});
    }
}
