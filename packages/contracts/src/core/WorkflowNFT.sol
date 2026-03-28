// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

import {IWorkflowNFT} from "../interfaces/IWorkflowNFT.sol";
import {IWorkflowRegistry} from "../interfaces/IWorkflowRegistry.sol";
import {DataTypes} from "../types/DataTypes.sol";

/// @title WorkflowNFT
/// @notice ERC-721 token representing ownership of an Atlas workflow
/// @dev tokenId always equals the workflowId in the registry. Transferring
///      the NFT transfers workflow ownership via the registry.
contract WorkflowNFT is
    IWorkflowNFT,
    ERC721Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using Strings for uint256;
    using Strings for uint8;

    /// @notice The workflow registry this NFT contract is bound to
    IWorkflowRegistry public registry;

    /// @notice Optional base URI for external metadata
    string private _externalBaseURI;

    error ZeroAddress();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the WorkflowNFT contract
    /// @param owner_ The contract owner (can set base URI and authorize upgrades)
    /// @param registry_ The WorkflowRegistry address
    function initialize(address owner_, address registry_) external initializer {
        if (registry_ == address(0)) revert ZeroAddress();

        __ERC721_init("Atlas Workflow", "ATLWF");
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();

        registry = IWorkflowRegistry(registry_);
    }

    // ==================== External functions ====================

    /// @inheritdoc IWorkflowNFT
    function createWorkflow(
        DataTypes.Step[] calldata steps,
        uint256 rewardPerStep
    ) external payable returns (uint256 tokenId) {
        // Forward the call to registry — it creates the workflow with msg.sender as owner
        tokenId = registry.createWorkflowFor{value: msg.value}(
            msg.sender,
            steps,
            rewardPerStep
        );

        // Mint the NFT to the caller — tokenId == workflowId
        _mint(msg.sender, tokenId);

        emit WorkflowMinted(tokenId, msg.sender);
    }

    /// @inheritdoc IWorkflowNFT
    function workflowIdOf(uint256 tokenId) external pure returns (uint256) {
        return tokenId;
    }

    /// @notice Sets an optional base URI for external metadata
    /// @param baseURI_ The new base URI
    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _externalBaseURI = baseURI_;
    }

    // ==================== Token URI ====================

    /// @notice Returns on-chain JSON metadata for the workflow NFT
    /// @dev If a base URI is set, returns baseURI + tokenId instead
    /// @param tokenId The token ID to query
    /// @return The token URI as a data URI or external URL
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        // If external base URI is set, use it
        if (bytes(_externalBaseURI).length > 0) {
            return string.concat(_externalBaseURI, tokenId.toString());
        }

        // Build on-chain JSON metadata
        DataTypes.Workflow memory wf = registry.getWorkflow(tokenId);

        string memory statusStr = _statusToString(wf.status);

        string memory json = string.concat(
            '{"name":"Atlas Workflow #',
            tokenId.toString(),
            '","description":"An Atlas Protocol workflow NFT",'
            '"attributes":[{"trait_type":"Status","value":"',
            statusStr,
            '"},{"trait_type":"Total Steps","display_type":"number","value":',
            wf.totalSteps.toString(),
            '},{"trait_type":"Current Step","display_type":"number","value":',
            wf.currentStepIndex.toString(),
            '},{"trait_type":"Reward Per Step","display_type":"number","value":',
            wf.rewardPerStep.toString(),
            "}]}"
        );

        return string.concat(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        );
    }

    // ==================== Internal functions ====================

    /// @dev Overrides ERC721 _update to sync ownership with the registry on transfers.
    ///      Mints (from == address(0)) and burns (to == address(0)) do not call
    ///      setWorkflowOwner — the registry already has the correct owner on mint,
    ///      and burns are not supported.
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address from) {
        from = super._update(to, tokenId, auth);

        // On transfers (not mints and not burns), update the registry
        if (from != address(0) && to != address(0)) {
            registry.setWorkflowOwner(tokenId, to);
        }

        return from;
    }

    /// @dev Only the owner can authorize upgrades
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @dev Converts a WorkflowStatus enum to its string representation
    function _statusToString(DataTypes.WorkflowStatus status) internal pure returns (string memory) {
        if (status == DataTypes.WorkflowStatus.ACTIVE) return "Active";
        if (status == DataTypes.WorkflowStatus.PAUSED) return "Paused";
        if (status == DataTypes.WorkflowStatus.COMPLETED) return "Completed";
        if (status == DataTypes.WorkflowStatus.FAILED) return "Failed";
        return "None";
    }
}
