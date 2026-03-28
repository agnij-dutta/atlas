// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {WorkflowRegistry} from "../../src/core/WorkflowRegistry.sol";
import {WorkflowNFT} from "../../src/core/WorkflowNFT.sol";
import {IWorkflowNFT} from "../../src/interfaces/IWorkflowNFT.sol";
import {IWorkflowRegistry} from "../../src/interfaces/IWorkflowRegistry.sol";
import {DataTypes} from "../../src/types/DataTypes.sol";

contract WorkflowNFTTest is Test {
    WorkflowRegistry public registry;
    WorkflowNFT public nft;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public attacker = makeAddr("attacker");

    uint256 public constant DEFAULT_REWARD = 0.001 ether;

    function setUp() public {
        // Deploy registry behind proxy
        WorkflowRegistry registryImpl = new WorkflowRegistry();
        ERC1967Proxy registryProxy = new ERC1967Proxy(
            address(registryImpl),
            abi.encodeCall(WorkflowRegistry.initialize, (owner))
        );
        registry = WorkflowRegistry(address(registryProxy));

        // Deploy NFT behind proxy
        WorkflowNFT nftImpl = new WorkflowNFT();
        ERC1967Proxy nftProxy = new ERC1967Proxy(
            address(nftImpl),
            abi.encodeCall(WorkflowNFT.initialize, (owner, address(registry)))
        );
        nft = WorkflowNFT(address(nftProxy));

        // Register NFT contract with registry
        vm.prank(owner);
        registry.setWorkflowNFTAddress(address(nft));

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(owner, 100 ether);
        vm.deal(attacker, 100 ether);
    }

    // ==================== Helpers ====================

    function _buildStep() internal pure returns (DataTypes.Step memory) {
        return DataTypes.Step({
            stepType: DataTypes.StepType.CONTRACT_CALL,
            target: address(1),
            callData: abi.encodeWithSignature("foo()"),
            value: 0,
            delay: 0,
            conditionData: ""
        });
    }

    function _createNFTWorkflow(address caller) internal returns (uint256) {
        DataTypes.Step[] memory steps = new DataTypes.Step[](2);
        steps[0] = _buildStep();
        steps[1] = _buildStep();

        uint256 totalCost = DEFAULT_REWARD * 2;
        vm.prank(caller);
        return nft.createWorkflow{value: totalCost}(steps, DEFAULT_REWARD);
    }

    // ==================== createWorkflow ====================

    function test_createWorkflow_mintsNFTWithCorrectTokenId() public {
        uint256 tokenId = _createNFTWorkflow(alice);

        // tokenId should be 1 (first workflow)
        assertEq(tokenId, 1);
        // Alice owns the NFT
        assertEq(nft.ownerOf(tokenId), alice);
        // Balance is 1
        assertEq(nft.balanceOf(alice), 1);
    }

    function test_createWorkflow_registersWorkflowInRegistry() public {
        uint256 tokenId = _createNFTWorkflow(alice);

        DataTypes.Workflow memory wf = registry.getWorkflow(tokenId);
        assertEq(wf.id, tokenId);
        assertEq(wf.owner, alice);
        assertEq(wf.totalSteps, 2);
        assertEq(wf.rewardPerStep, DEFAULT_REWARD);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.ACTIVE));
    }

    function test_createWorkflow_emitsWorkflowMinted() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](1);
        steps[0] = _buildStep();

        vm.expectEmit(true, true, false, false, address(nft));
        emit IWorkflowNFT.WorkflowMinted(1, alice);

        vm.prank(alice);
        nft.createWorkflow{value: DEFAULT_REWARD}(steps, DEFAULT_REWARD);
    }

    function test_createWorkflow_workflowIdOfReturnsTokenId() public {
        uint256 tokenId = _createNFTWorkflow(alice);
        assertEq(nft.workflowIdOf(tokenId), tokenId);
    }

    function test_createWorkflow_multipleWorkflows() public {
        uint256 id1 = _createNFTWorkflow(alice);
        uint256 id2 = _createNFTWorkflow(bob);

        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(nft.ownerOf(id1), alice);
        assertEq(nft.ownerOf(id2), bob);
    }

    // ==================== tokenURI ====================

    function test_tokenURI_returnsValidJSON() public {
        uint256 tokenId = _createNFTWorkflow(alice);

        string memory uri = nft.tokenURI(tokenId);

        // Should start with data URI prefix
        assertTrue(_startsWith(uri, "data:application/json;base64,"));

        // Decode and check it contains expected fields
        string memory jsonPart = _removePrefix(uri, "data:application/json;base64,");
        bytes memory decoded = _base64Decode(jsonPart);
        string memory json = string(decoded);

        // Check that the JSON contains expected substrings
        assertTrue(_contains(json, "Atlas Workflow #1"));
        assertTrue(_contains(json, "Active"));
        assertTrue(_contains(json, "Total Steps"));
    }

    function test_tokenURI_revertsForNonexistentToken() public {
        vm.expectRevert();
        nft.tokenURI(999);
    }

    function test_tokenURI_usesBaseURIWhenSet() public {
        uint256 tokenId = _createNFTWorkflow(alice);

        vm.prank(owner);
        nft.setBaseURI("https://api.atlas.xyz/metadata/");

        string memory uri = nft.tokenURI(tokenId);
        assertEq(uri, "https://api.atlas.xyz/metadata/1");
    }

    // ==================== Transfer updates registry owner ====================

    function test_transfer_updatesRegistryOwner() public {
        uint256 tokenId = _createNFTWorkflow(alice);

        // Transfer NFT from alice to bob
        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);

        // NFT owner is bob
        assertEq(nft.ownerOf(tokenId), bob);

        // Registry owner should also be bob
        DataTypes.Workflow memory wf = registry.getWorkflow(tokenId);
        assertEq(wf.owner, bob);
    }

    function test_transfer_emitsOwnerChanged() public {
        uint256 tokenId = _createNFTWorkflow(alice);

        vm.expectEmit(true, true, false, false, address(registry));
        emit IWorkflowRegistry.WorkflowOwnerChanged(tokenId, bob);

        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);
    }

    function test_safeTransfer_updatesRegistryOwner() public {
        uint256 tokenId = _createNFTWorkflow(alice);

        vm.prank(alice);
        nft.safeTransferFrom(alice, bob, tokenId);

        assertEq(nft.ownerOf(tokenId), bob);
        DataTypes.Workflow memory wf = registry.getWorkflow(tokenId);
        assertEq(wf.owner, bob);
    }

    // ==================== Access control: setWorkflowOwner ====================

    function test_setWorkflowOwner_revertsWhenCalledByNonNFT() public {
        _createNFTWorkflow(alice);

        vm.prank(attacker);
        vm.expectRevert(WorkflowRegistry.NotWorkflowNFT.selector);
        registry.setWorkflowOwner(1, attacker);
    }

    function test_setWorkflowOwner_revertsWhenCalledByOwner() public {
        _createNFTWorkflow(alice);

        vm.prank(owner);
        vm.expectRevert(WorkflowRegistry.NotWorkflowNFT.selector);
        registry.setWorkflowOwner(1, owner);
    }

    // ==================== Access control: createWorkflowFor ====================

    function test_createWorkflowFor_revertsWhenCalledByNonNFT() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](1);
        steps[0] = _buildStep();

        vm.prank(attacker);
        vm.expectRevert(WorkflowRegistry.NotWorkflowNFT.selector);
        registry.createWorkflowFor{value: DEFAULT_REWARD}(attacker, steps, DEFAULT_REWARD);
    }

    function test_createWorkflowFor_revertsWhenCalledByOwner() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](1);
        steps[0] = _buildStep();

        vm.prank(owner);
        vm.expectRevert(WorkflowRegistry.NotWorkflowNFT.selector);
        registry.createWorkflowFor{value: DEFAULT_REWARD}(owner, steps, DEFAULT_REWARD);
    }

    // ==================== setWorkflowNFTAddress ====================

    function test_setWorkflowNFTAddress_revertsOnSecondCall() public {
        vm.prank(owner);
        vm.expectRevert(WorkflowRegistry.WorkflowNFTAlreadySet.selector);
        registry.setWorkflowNFTAddress(address(0xdead));
    }

    function test_setWorkflowNFTAddress_revertsForNonOwner() public {
        // Deploy fresh registry to test
        WorkflowRegistry freshImpl = new WorkflowRegistry();
        ERC1967Proxy freshProxy = new ERC1967Proxy(
            address(freshImpl),
            abi.encodeCall(WorkflowRegistry.initialize, (owner))
        );
        WorkflowRegistry freshRegistry = WorkflowRegistry(address(freshProxy));

        vm.prank(attacker);
        vm.expectRevert();
        freshRegistry.setWorkflowNFTAddress(address(nft));
    }

    // ==================== Backward compatibility ====================

    function test_originalCreateWorkflow_stillWorks() public {
        DataTypes.Step[] memory steps = new DataTypes.Step[](1);
        steps[0] = _buildStep();

        vm.prank(alice);
        uint256 wfId = registry.createWorkflow{value: DEFAULT_REWARD}(steps, DEFAULT_REWARD);

        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(wf.owner, alice);
        assertEq(wf.totalSteps, 1);
    }

    // ==================== String helpers ====================

    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);
        if (strBytes.length < prefixBytes.length) return false;
        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) return false;
        }
        return true;
    }

    function _removePrefix(string memory str, string memory prefix) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);
        bytes memory result = new bytes(strBytes.length - prefixBytes.length);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = strBytes[i + prefixBytes.length];
        }
        return string(result);
    }

    function _contains(string memory str, string memory sub) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory subBytes = bytes(sub);
        if (subBytes.length > strBytes.length) return false;
        for (uint256 i = 0; i <= strBytes.length - subBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < subBytes.length; j++) {
                if (strBytes[i + j] != subBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }

    /// @dev Minimal Base64 decode for testing purposes
    function _base64Decode(string memory data) internal pure returns (bytes memory) {
        bytes memory input = bytes(data);
        uint256 len = input.length;
        require(len % 4 == 0, "Invalid base64");

        uint256 decodedLen = (len / 4) * 3;
        if (input[len - 1] == "=") decodedLen--;
        if (input[len - 2] == "=") decodedLen--;

        bytes memory output = new bytes(decodedLen);
        uint256 idx = 0;

        for (uint256 i = 0; i < len; i += 4) {
            uint256 a = _base64CharValue(input[i]);
            uint256 b = _base64CharValue(input[i + 1]);
            uint256 c = _base64CharValue(input[i + 2]);
            uint256 d = _base64CharValue(input[i + 3]);

            uint256 triple = (a << 18) | (b << 12) | (c << 6) | d;

            if (idx < decodedLen) output[idx++] = bytes1(uint8((triple >> 16) & 0xFF));
            if (idx < decodedLen) output[idx++] = bytes1(uint8((triple >> 8) & 0xFF));
            if (idx < decodedLen) output[idx++] = bytes1(uint8(triple & 0xFF));
        }

        return output;
    }

    function _base64CharValue(bytes1 c) internal pure returns (uint256) {
        if (c >= "A" && c <= "Z") return uint8(c) - 65;
        if (c >= "a" && c <= "z") return uint8(c) - 71;
        if (c >= "0" && c <= "9") return uint8(c) + 4;
        if (c == "+") return 62;
        if (c == "/") return 63;
        return 0; // padding '='
    }
}
