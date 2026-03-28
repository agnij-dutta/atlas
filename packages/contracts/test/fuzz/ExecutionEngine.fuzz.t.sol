// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestSetup} from "../helpers/TestSetup.sol";
import {DataTypes} from "../../src/types/DataTypes.sol";
import {ExecutionEngine} from "../../src/core/ExecutionEngine.sol";

contract ExecutionEngineFuzzTest is TestSetup {
    /// @notice Fuzz rewardPerStep and stepCount: total deposit always matches
    function testFuzz_rewardAndStepCount_depositMatchesTotalReward(
        uint8 stepCountRaw,
        uint96 rewardPerStepRaw
    ) public {
        // Bound inputs to sane ranges
        uint256 stepCount = bound(uint256(stepCountRaw), 1, 10);
        uint256 rewardPerStep = bound(uint256(rewardPerStepRaw), 0.0001 ether, 1 ether);

        uint256 totalReward = rewardPerStep * stepCount;

        // Create the workflow
        DataTypes.Step[] memory steps = new DataTypes.Step[](stepCount);
        for (uint256 i = 0; i < stepCount; i++) {
            steps[i] = _buildContractCallStep(i + 1);
        }

        vm.prank(alice);
        uint256 wfId = registry.createWorkflow{value: totalReward}(steps, rewardPerStep);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);

        // Invariant: the stored reward balance equals the total deposit
        assertEq(wf.rewardBalance, totalReward);
        assertEq(wf.rewardPerStep, rewardPerStep);
        assertEq(wf.totalSteps, stepCount);

        // Invariant: totalReward == rewardPerStep * totalSteps
        assertEq(wf.rewardBalance, wf.rewardPerStep * wf.totalSteps);
    }

    /// @notice Fuzz delay values: step never executes before delay elapses
    function testFuzz_delayStep_neverExecutesBefore(uint32 delayRaw) public {
        uint256 delaySeconds = bound(uint256(delayRaw), 1, 30 days);

        // Create a 2-step workflow: CONTRACT_CALL then DELAY
        DataTypes.Step[] memory steps = new DataTypes.Step[](2);
        steps[0] = _buildContractCallStep(1);
        steps[1] = _buildDelayStep(delaySeconds);

        uint256 totalReward = DEFAULT_REWARD * 2;

        vm.prank(alice);
        uint256 wfId = registry.createWorkflow{value: totalReward}(steps, DEFAULT_REWARD);


        // Execute step 0 to set lastExecutedAt
        vm.prank(executor);
        engine.executeStep(wfId);

        // Immediately after, isStepReady should be false (delay > 0)
        assertFalse(engine.isStepReady(wfId));

        // Warp to just before the delay expires
        vm.warp(block.timestamp + delaySeconds - 1);
        assertFalse(engine.isStepReady(wfId));

        // Warp to exactly the delay boundary
        vm.warp(block.timestamp + 1);
        assertTrue(engine.isStepReady(wfId));
    }
}
