// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IExecutionAuction {
    // ── Structs ──────────────────────────────────────────────────────────

    struct Auction {
        uint256 workflowId;
        uint256 stepIndex;
        uint128 startPrice;
        uint128 floorPrice;
        uint64 startBlock;
        uint64 duration;
        bool settled;
    }

    // ── Events ───────────────────────────────────────────────────────────

    event AuctionStarted(
        uint256 indexed workflowId,
        uint256 stepIndex,
        uint128 startPrice,
        uint128 floorPrice,
        uint64 startBlock,
        uint64 duration
    );
    event AuctionSettled(
        uint256 indexed workflowId,
        address indexed executor,
        uint256 pricePaid,
        uint256 surplus
    );

    // ── Errors ───────────────────────────────────────────────────────────

    error AuctionAlreadyActive(uint256 workflowId);
    error StepNotReady(uint256 workflowId);
    error NoActiveAuction(uint256 workflowId);
    error AuctionAlreadySettled(uint256 workflowId);

    // ── Functions ────────────────────────────────────────────────────────

    function startAuction(uint256 workflowId) external;
    function getCurrentPrice(uint256 workflowId) external view returns (uint256);
    function executeWithBid(uint256 workflowId) external;
    function getAuction(uint256 workflowId) external view returns (Auction memory);
}
