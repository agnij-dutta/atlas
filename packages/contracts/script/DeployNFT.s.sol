// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {WorkflowRegistry} from "../src/core/WorkflowRegistry.sol";
import {WorkflowNFT} from "../src/core/WorkflowNFT.sol";

/// @title DeployNFT
/// @notice Deploys WorkflowNFT behind a UUPS proxy and registers it with an existing registry
contract DeployNFT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        WorkflowNFT nftImpl = new WorkflowNFT();

        // Deploy proxy
        ERC1967Proxy nftProxy = new ERC1967Proxy(
            address(nftImpl),
            abi.encodeCall(WorkflowNFT.initialize, (deployer, registryAddress))
        );

        WorkflowNFT nft = WorkflowNFT(address(nftProxy));

        // Register NFT with registry (one-time setup)
        WorkflowRegistry(registryAddress).setWorkflowNFTAddress(address(nft));

        console2.log("WorkflowNFT implementation:", address(nftImpl));
        console2.log("WorkflowNFT proxy:", address(nftProxy));

        vm.stopBroadcast();
    }
}
