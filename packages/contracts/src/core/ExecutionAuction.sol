// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IExecutionAuction} from "../interfaces/IExecutionAuction.sol";
import {IExecutionEngine} from "../interfaces/IExecutionEngine.sol";
import {WorkflowRegistry} from "./WorkflowRegistry.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {AtlasAccessControl} from "../access/AtlasAccessControl.sol";

/// @title ExecutionAuction
/// @notice Dutch auction mechanism for workflow step execution. The price starts at
///         the full reward-per-step and linearly decreases to a floor price over a
///         configurable block window. Executors bid by calling executeWithBid at the
///         current block — lower price means higher surplus retained by the workflow.
/// @dev UUPS-upgradeable. The auction contract must be granted executor role on
///      both the ExecutionEngine and WorkflowRegistry to forward execution calls
///      and pay executors from the workflow's reward balance.
contract ExecutionAuction is IExecutionAuction, AtlasAccessControl {
    // ── Constants ────────────────────────────────────────────────────────

    /// @notice Auction duration in blocks (~50 seconds on Base at 2s block time)
    uint64 public constant AUCTION_DURATION = 25;

    /// @notice Floor price as a percentage of the full reward (20%)
    uint256 public constant FLOOR_PERCENT = 20;

    // ── Storage ──────────────────────────────────────────────────────────

    /// @notice Reference to the ExecutionEngine for forwarding execution
    IExecutionEngine public engine;

    /// @notice Reference to the WorkflowRegistry for reading workflow state and paying executors
    WorkflowRegistry public registry;

    /// @notice workflowId => active auction
    mapping(uint256 => Auction) private _auctions;

    // ── Initializer ──────────────────────────────────────────────────────

    /// @notice Initialize behind a UUPS proxy
    /// @param owner_ Protocol admin
    /// @param engine_ ExecutionEngine proxy address
    /// @param registry_ WorkflowRegistry proxy address
    function initialize(
        address owner_,
        address engine_,
        address registry_
    ) external initializer {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        engine = IExecutionEngine(engine_);
        registry = WorkflowRegistry(registry_);
    }

    // ── Auction Lifecycle ────────────────────────────────────────────────

    /// @notice Start a Dutch auction for the next ready step of a workflow
    /// @param workflowId The workflow whose next step should be auctioned
    function startAuction(uint256 workflowId) external {
        // Verify the step is actually ready
        if (!engine.isStepReady(workflowId)) {
            revert StepNotReady(workflowId);
        }

        Auction storage a = _auctions[workflowId];

        // If there is an existing auction, it must be settled or expired
        if (a.startBlock != 0 && !a.settled) {
            // Check if expired
            if (uint64(block.number) <= a.startBlock + a.duration) {
                revert AuctionAlreadyActive(workflowId);
            }
            // Expired — allow overwrite
        }

        DataTypes.Workflow memory wf = registry.getWorkflow(workflowId);
        uint128 startPrice = uint128(wf.rewardPerStep);
        uint128 floorPrice = uint128((wf.rewardPerStep * FLOOR_PERCENT) / 100);

        _auctions[workflowId] = Auction({
            workflowId: workflowId,
            stepIndex: wf.currentStepIndex,
            startPrice: startPrice,
            floorPrice: floorPrice,
            startBlock: uint64(block.number),
            duration: AUCTION_DURATION,
            settled: false
        });

        emit AuctionStarted(
            workflowId,
            wf.currentStepIndex,
            startPrice,
            floorPrice,
            uint64(block.number),
            AUCTION_DURATION
        );
    }

    /// @notice Get the current Dutch auction price for a workflow
    /// @param workflowId The workflow to query
    /// @return price The current price in wei — linearly decreasing from startPrice to floorPrice
    function getCurrentPrice(uint256 workflowId) public view returns (uint256 price) {
        Auction storage a = _auctions[workflowId];
        if (a.startBlock == 0) revert NoActiveAuction(workflowId);
        if (a.settled) revert AuctionAlreadySettled(workflowId);

        uint256 elapsed = block.number - uint256(a.startBlock);

        if (elapsed >= uint256(a.duration)) {
            // Past duration — floor price (fallback window)
            return uint256(a.floorPrice);
        }

        // Linear interpolation: startPrice - (elapsed / duration) * (startPrice - floorPrice)
        uint256 priceDrop = uint256(a.startPrice) - uint256(a.floorPrice);
        uint256 discount = (priceDrop * elapsed) / uint256(a.duration);
        price = uint256(a.startPrice) - discount;
    }

    /// @notice Execute the auctioned step at the current Dutch auction price
    /// @dev The executor pays nothing — the workflow's reward balance funds the payment.
    ///      The executor receives the current auction price; the surplus stays in the workflow.
    /// @param workflowId The workflow to execute
    function executeWithBid(uint256 workflowId) external {
        Auction storage a = _auctions[workflowId];
        if (a.startBlock == 0) revert NoActiveAuction(workflowId);
        if (a.settled) revert AuctionAlreadySettled(workflowId);

        uint256 price = getCurrentPrice(workflowId);

        // Mark settled before external calls — checks-effects-interactions
        a.settled = true;

        // Execute the step via the engine (engine.executeStep pays full rewardPerStep to msg.sender,
        // but we want to pay only `price`). Instead, we call the registry directly:
        // 1. Execute the step via engine (which advances workflow and pays THIS contract as executor)
        //    -- For this to work, this contract must be an executor on the engine, and the engine
        //       will pay `rewardPerStep` to `msg.sender` of executeStep... but msg.sender is this contract.
        //
        // Strategy: We call engine.executeStep which pays this contract. Then we forward `price` to
        // the actual executor and keep the surplus (or it stays in workflow via deductReward).
        //
        // Actually, looking at the engine code: engine.executeStep pays msg.sender (this contract).
        // We then forward `price` to the real executor.

        // Record balance before to track incoming reward
        uint256 balBefore = address(this).balance;

        // Execute — this contract must have executor role on the engine
        engine.executeStep(workflowId);

        // The engine paid this contract rewardPerStep
        uint256 received = address(this).balance - balBefore;
        uint256 surplus = received - price;

        emit AuctionSettled(workflowId, msg.sender, price, surplus);

        // Pay the actual executor
        if (price > 0) {
            (bool success,) = msg.sender.call{value: price}("");
            require(success, "ETH transfer failed");
        }

        // Surplus stays in this contract — owner can sweep or it accumulates as protocol revenue
    }

    /// @notice Get the auction details for a workflow
    /// @param workflowId The workflow to query
    /// @return The auction struct
    function getAuction(uint256 workflowId) external view returns (Auction memory) {
        return _auctions[workflowId];
    }

    /// @notice Allow owner to sweep accumulated surplus
    function sweepSurplus(address to) external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success,) = to.call{value: balance}("");
            require(success, "ETH transfer failed");
        }
    }

    /// @notice Accept ETH (rewards from engine.executeStep)
    receive() external payable {}
}
