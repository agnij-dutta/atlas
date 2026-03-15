// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library TimeTriggerLib {
    function isTimeMet(uint256 lastExecution, uint256 interval) internal view returns (bool) {
        if (lastExecution == 0) return true;
        return block.timestamp >= lastExecution + interval;
    }

    function timeUntilNext(uint256 lastExecution, uint256 interval) internal view returns (uint256) {
        if (lastExecution == 0) return 0;
        uint256 nextTime = lastExecution + interval;
        if (block.timestamp >= nextTime) return 0;
        return nextTime - block.timestamp;
    }
}
