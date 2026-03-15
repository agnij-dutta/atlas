// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }

    function failAlways() external pure {
        revert("always fails");
    }

    function checkCondition() external pure returns (bool) {
        return true;
    }
}
