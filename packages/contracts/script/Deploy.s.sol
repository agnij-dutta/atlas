// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {WorkflowRegistry} from "../src/core/WorkflowRegistry.sol";
import {ExecutionEngine} from "../src/core/ExecutionEngine.sol";
import {RewardManager} from "../src/core/RewardManager.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementations
        WorkflowRegistry registryImpl = new WorkflowRegistry();
        ExecutionEngine engineImpl = new ExecutionEngine();
        RewardManager rewardImpl = new RewardManager();

        // Deploy proxies
        ERC1967Proxy registryProxy = new ERC1967Proxy(
            address(registryImpl),
            abi.encodeCall(WorkflowRegistry.initialize, (deployer))
        );
        ERC1967Proxy rewardProxy = new ERC1967Proxy(
            address(rewardImpl),
            abi.encodeCall(RewardManager.initialize, (deployer))
        );
        ERC1967Proxy engineProxy = new ERC1967Proxy(
            address(engineImpl),
            abi.encodeCall(ExecutionEngine.initialize, (deployer, address(registryProxy), address(rewardProxy)))
        );

        // Grant executor role to ExecutionEngine on Registry and RewardManager
        WorkflowRegistry(address(registryProxy)).addExecutor(address(engineProxy));
        RewardManager(payable(address(rewardProxy))).addExecutor(address(engineProxy));

        console2.log("WorkflowRegistry:", address(registryProxy));
        console2.log("ExecutionEngine:", address(engineProxy));
        console2.log("RewardManager:", address(rewardProxy));

        vm.stopBroadcast();
    }
}
