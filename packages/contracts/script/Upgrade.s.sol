// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {WorkflowRegistry} from "../src/core/WorkflowRegistry.sol";
import {ExecutionEngine} from "../src/core/ExecutionEngine.sol";
import {RewardManager} from "../src/core/RewardManager.sol";

contract Upgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address registryProxy = vm.envAddress("REGISTRY_PROXY");
        address engineProxy = vm.envAddress("ENGINE_PROXY");
        address rewardProxy = vm.envAddress("REWARD_PROXY");

        vm.startBroadcast(deployerPrivateKey);

        WorkflowRegistry newRegistry = new WorkflowRegistry();
        ExecutionEngine newEngine = new ExecutionEngine();
        RewardManager newReward = new RewardManager();

        WorkflowRegistry(registryProxy).upgradeToAndCall(address(newRegistry), "");
        ExecutionEngine(engineProxy).upgradeToAndCall(address(newEngine), "");
        RewardManager(payable(rewardProxy)).upgradeToAndCall(address(newReward), "");

        console2.log("Upgraded Registry to:", address(newRegistry));
        console2.log("Upgraded Engine to:", address(newEngine));
        console2.log("Upgraded Reward to:", address(newReward));

        vm.stopBroadcast();
    }
}
