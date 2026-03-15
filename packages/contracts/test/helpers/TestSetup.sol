// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {WorkflowRegistry} from "../../src/core/WorkflowRegistry.sol";
import {ExecutionEngine} from "../../src/core/ExecutionEngine.sol";
import {RewardManager} from "../../src/core/RewardManager.sol";
import {DataTypes} from "../../src/types/DataTypes.sol";
import {MockTarget} from "./MockTarget.sol";

/// @title TestSetup
/// @notice Base test contract that deploys all Atlas contracts behind UUPS proxies
abstract contract TestSetup is Test {
    WorkflowRegistry public registry;
    ExecutionEngine public engine;
    RewardManager public rewardManager;
    MockTarget public mockTarget;

    address public owner = makeAddr("owner");
    address public executor = makeAddr("executor");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant DEFAULT_REWARD = 0.001 ether;

    function setUp() public virtual {
        // Deploy implementations
        WorkflowRegistry registryImpl = new WorkflowRegistry();
        ExecutionEngine engineImpl = new ExecutionEngine();
        RewardManager rewardManagerImpl = new RewardManager();

        // Deploy proxies
        ERC1967Proxy registryProxy = new ERC1967Proxy(
            address(registryImpl),
            abi.encodeCall(WorkflowRegistry.initialize, (owner))
        );
        ERC1967Proxy rewardManagerProxy = new ERC1967Proxy(
            address(rewardManagerImpl),
            abi.encodeCall(RewardManager.initialize, (owner))
        );
        ERC1967Proxy engineProxy = new ERC1967Proxy(
            address(engineImpl),
            abi.encodeCall(
                ExecutionEngine.initialize,
                (owner, address(registryProxy), address(rewardManagerProxy))
            )
        );

        registry = WorkflowRegistry(address(registryProxy));
        rewardManager = RewardManager(payable(address(rewardManagerProxy)));
        engine = ExecutionEngine(address(engineProxy));

        mockTarget = new MockTarget();

        // Grant executor role on all contracts
        vm.startPrank(owner);
        registry.addExecutor(address(engine));
        registry.addExecutor(executor);
        rewardManager.addExecutor(address(engine));
        rewardManager.addExecutor(executor);
        engine.addExecutor(executor);
        vm.stopPrank();

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(executor, 100 ether);
        vm.deal(owner, 100 ether);
    }

    // --------------- Helpers ---------------

    /// @notice Build a single CONTRACT_CALL step targeting mockTarget.setValue
    function _buildContractCallStep(uint256 val) internal view returns (DataTypes.Step memory) {
        return DataTypes.Step({
            stepType: DataTypes.StepType.CONTRACT_CALL,
            target: address(mockTarget),
            callData: abi.encodeCall(MockTarget.setValue, (val)),
            value: 0,
            delay: 0,
            conditionData: ""
        });
    }

    /// @notice Build a DELAY step
    function _buildDelayStep(uint256 delaySeconds) internal pure returns (DataTypes.Step memory) {
        return DataTypes.Step({
            stepType: DataTypes.StepType.DELAY,
            target: address(0),
            callData: "",
            value: 0,
            delay: delaySeconds,
            conditionData: ""
        });
    }

    /// @notice Create a simple 1-step workflow as alice and return the workflow id
    function _createSimpleWorkflow() internal returns (uint256) {
        DataTypes.Step[] memory steps = new DataTypes.Step[](1);
        steps[0] = _buildContractCallStep(42);

        vm.prank(alice);
        return registry.createWorkflow{value: DEFAULT_REWARD}(steps, DEFAULT_REWARD);
    }

    /// @notice Create a multi-step workflow as alice and return the workflow id
    function _createMultiStepWorkflow(uint256 numSteps, uint256 rewardPerStep)
        internal
        returns (uint256)
    {
        DataTypes.Step[] memory steps = new DataTypes.Step[](numSteps);
        for (uint256 i = 0; i < numSteps; i++) {
            steps[i] = _buildContractCallStep(i + 1);
        }

        uint256 totalReward = rewardPerStep * numSteps;
        vm.prank(alice);
        return registry.createWorkflow{value: totalReward}(steps, rewardPerStep);
    }
}
