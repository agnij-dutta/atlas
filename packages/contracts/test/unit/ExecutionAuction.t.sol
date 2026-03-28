// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestSetup} from "../helpers/TestSetup.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ExecutionAuction} from "../../src/core/ExecutionAuction.sol";
import {IExecutionAuction} from "../../src/interfaces/IExecutionAuction.sol";
import {DataTypes} from "../../src/types/DataTypes.sol";

/// @title ExecutionAuctionTest
/// @notice Unit tests for the ExecutionAuction Dutch auction mechanism
contract ExecutionAuctionTest is TestSetup {
    ExecutionAuction public auction;

    uint256 public constant AUCTION_DURATION = 25;
    uint256 public constant FLOOR_PERCENT = 20;

    function setUp() public override {
        super.setUp();

        // Deploy auction behind UUPS proxy
        ExecutionAuction auctionImpl = new ExecutionAuction();
        ERC1967Proxy auctionProxy = new ERC1967Proxy(
            address(auctionImpl),
            abi.encodeCall(
                ExecutionAuction.initialize,
                (owner, address(engine), address(registry))
            )
        );
        auction = ExecutionAuction(payable(address(auctionProxy)));

        // The auction contract needs executor role on the engine (to call executeStep)
        // and the engine needs the auction as executor on registry (engine already has it)
        vm.startPrank(owner);
        engine.addExecutor(address(auction));
        // The auction also needs executor role on registry to be able to call payExecutor
        // through the engine (engine calls registry.payExecutor which checks onlyExecutor)
        // Actually engine.executeStep uses msg.sender which will be the auction contract,
        // and engine checks onlyExecutor on its own executeStep.
        // The engine then calls registry.payExecutor — registry checks onlyExecutor.
        // Engine is already an executor on registry. So the flow is:
        // auction -> engine.executeStep (auction must be executor on engine) -> registry.payExecutor (engine is executor on registry)
        // The engine pays the executor (msg.sender of engine.executeStep) which is the auction contract.
        vm.stopPrank();
    }

    // ==================== startAuction ====================

    function test_startAuction_createsAuction() public {
        uint256 wfId = _createSimpleWorkflow();

        auction.startAuction(wfId);

        IExecutionAuction.Auction memory a = auction.getAuction(wfId);
        assertEq(a.workflowId, wfId);
        assertEq(a.stepIndex, 0);
        assertEq(a.startPrice, uint128(DEFAULT_REWARD));
        assertEq(a.floorPrice, uint128((DEFAULT_REWARD * FLOOR_PERCENT) / 100));
        assertEq(a.startBlock, uint64(block.number));
        assertEq(a.duration, AUCTION_DURATION);
        assertFalse(a.settled);
    }

    function test_startAuction_emitsEvent() public {
        uint256 wfId = _createSimpleWorkflow();

        vm.expectEmit(true, false, false, true);
        emit IExecutionAuction.AuctionStarted(
            wfId,
            0,
            uint128(DEFAULT_REWARD),
            uint128((DEFAULT_REWARD * FLOOR_PERCENT) / 100),
            uint64(block.number),
            uint64(AUCTION_DURATION)
        );

        auction.startAuction(wfId);
    }

    function test_startAuction_revertsIfStepNotReady() public {
        // Non-existent workflow
        vm.expectRevert();
        auction.startAuction(9999);
    }

    function test_startAuction_revertsIfAlreadyActive() public {
        uint256 wfId = _createSimpleWorkflow();

        auction.startAuction(wfId);

        vm.expectRevert(abi.encodeWithSelector(IExecutionAuction.AuctionAlreadyActive.selector, wfId));
        auction.startAuction(wfId);
    }

    function test_startAuction_allowsRestartAfterExpiry() public {
        uint256 wfId = _createMultiStepWorkflow(3, DEFAULT_REWARD);

        auction.startAuction(wfId);

        // Roll past auction duration without settling
        vm.roll(block.number + AUCTION_DURATION + 1);

        // Should be able to start a new auction
        auction.startAuction(wfId);

        IExecutionAuction.Auction memory a = auction.getAuction(wfId);
        assertEq(a.startBlock, uint64(block.number));
        assertFalse(a.settled);
    }

    // ==================== getCurrentPrice ====================

    function test_getCurrentPrice_startsAtFullReward() public {
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);

        uint256 price = auction.getCurrentPrice(wfId);
        assertEq(price, DEFAULT_REWARD);
    }

    function test_getCurrentPrice_decreasesOverBlocks() public {
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);

        uint256 priceAtStart = auction.getCurrentPrice(wfId);

        // Roll forward halfway
        vm.roll(block.number + AUCTION_DURATION / 2);
        uint256 priceAtMid = auction.getCurrentPrice(wfId);

        assertLt(priceAtMid, priceAtStart);
        assertGt(priceAtMid, (DEFAULT_REWARD * FLOOR_PERCENT) / 100);
    }

    function test_getCurrentPrice_reachesFloorAtEnd() public {
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);

        // Roll to exactly the duration
        vm.roll(block.number + AUCTION_DURATION);
        uint256 priceAtEnd = auction.getCurrentPrice(wfId);

        uint256 floorPrice = (DEFAULT_REWARD * FLOOR_PERCENT) / 100;
        assertEq(priceAtEnd, floorPrice);
    }

    function test_getCurrentPrice_staysAtFloorPastDuration() public {
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);

        // Roll well past duration
        vm.roll(block.number + AUCTION_DURATION + 100);
        uint256 price = auction.getCurrentPrice(wfId);

        uint256 floorPrice = (DEFAULT_REWARD * FLOOR_PERCENT) / 100;
        assertEq(price, floorPrice);
    }

    function test_getCurrentPrice_revertsIfNoAuction() public {
        vm.expectRevert(abi.encodeWithSelector(IExecutionAuction.NoActiveAuction.selector, 1));
        auction.getCurrentPrice(1);
    }

    function test_getCurrentPrice_linearDecrease() public {
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);

        uint256 floorPrice = (DEFAULT_REWARD * FLOOR_PERCENT) / 100;
        uint256 priceDrop = DEFAULT_REWARD - floorPrice;

        // Check price at each block
        for (uint256 i = 0; i < AUCTION_DURATION; i++) {
            vm.roll(block.number + 1);
            uint256 actualPrice = auction.getCurrentPrice(wfId);
            uint256 elapsed = i + 1;
            uint256 expectedPrice = DEFAULT_REWARD - (priceDrop * elapsed) / AUCTION_DURATION;
            assertEq(actualPrice, expectedPrice);
        }
    }

    // ==================== executeWithBid ====================

    function test_executeWithBid_atStartPaysFullReward() public {
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);

        uint256 executorBalBefore = alice.balance;

        vm.prank(alice);
        auction.executeWithBid(wfId);

        // Alice receives the full reward (price at block 0 = startPrice = rewardPerStep)
        assertEq(alice.balance, executorBalBefore + DEFAULT_REWARD);

        // Verify auction is settled
        IExecutionAuction.Auction memory a = auction.getAuction(wfId);
        assertTrue(a.settled);
    }

    function test_executeWithBid_atMidPaysReducedReward() public {
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);

        // Roll forward halfway
        vm.roll(block.number + AUCTION_DURATION / 2);

        uint256 expectedPrice = auction.getCurrentPrice(wfId);
        uint256 executorBalBefore = alice.balance;

        vm.prank(alice);
        auction.executeWithBid(wfId);

        assertEq(alice.balance, executorBalBefore + expectedPrice);
        assertLt(expectedPrice, DEFAULT_REWARD);
    }

    function test_executeWithBid_afterExpiryPaysFloor() public {
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);

        // Roll past duration — fallback at floor price
        vm.roll(block.number + AUCTION_DURATION + 5);

        uint256 floorPrice = (DEFAULT_REWARD * FLOOR_PERCENT) / 100;
        uint256 executorBalBefore = alice.balance;

        vm.prank(alice);
        auction.executeWithBid(wfId);

        assertEq(alice.balance, executorBalBefore + floorPrice);
    }

    function test_executeWithBid_emitsSettledEvent() public {
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);

        vm.expectEmit(true, true, false, true);
        emit IExecutionAuction.AuctionSettled(wfId, alice, DEFAULT_REWARD, 0);

        vm.prank(alice);
        auction.executeWithBid(wfId);
    }

    function test_executeWithBid_executesTheStep() public {
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);

        vm.prank(alice);
        auction.executeWithBid(wfId);

        // Verify the contract call was executed
        assertEq(mockTarget.value(), 42);

        // Verify workflow advanced / completed
        DataTypes.Workflow memory wf = registry.getWorkflow(wfId);
        assertEq(uint8(wf.status), uint8(DataTypes.WorkflowStatus.COMPLETED));
    }

    function test_executeWithBid_revertsIfNoAuction() public {
        vm.expectRevert(abi.encodeWithSelector(IExecutionAuction.NoActiveAuction.selector, 1));
        vm.prank(alice);
        auction.executeWithBid(1);
    }

    function test_executeWithBid_revertsIfAlreadySettled() public {
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);

        vm.prank(alice);
        auction.executeWithBid(wfId);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IExecutionAuction.AuctionAlreadySettled.selector, wfId));
        auction.executeWithBid(wfId);
    }

    function test_executeWithBid_surplusStaysInAuctionContract() public {
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);

        // Roll halfway so there's a surplus
        vm.roll(block.number + AUCTION_DURATION / 2);

        uint256 price = auction.getCurrentPrice(wfId);
        uint256 expectedSurplus = DEFAULT_REWARD - price;

        uint256 auctionBalBefore = address(auction).balance;

        vm.prank(alice);
        auction.executeWithBid(wfId);

        assertEq(address(auction).balance, auctionBalBefore + expectedSurplus);
    }

    // ==================== sweepSurplus ====================

    function test_sweepSurplus_ownerCanSweep() public {
        // Create surplus by executing at reduced price
        uint256 wfId = _createSimpleWorkflow();
        auction.startAuction(wfId);
        vm.roll(block.number + AUCTION_DURATION / 2);
        vm.prank(alice);
        auction.executeWithBid(wfId);

        uint256 surplus = address(auction).balance;
        assertGt(surplus, 0);

        uint256 ownerBalBefore = owner.balance;

        vm.prank(owner);
        auction.sweepSurplus(owner);

        assertEq(address(auction).balance, 0);
        assertEq(owner.balance, ownerBalBefore + surplus);
    }

    function test_sweepSurplus_revertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        auction.sweepSurplus(alice);
    }

    // ==================== getAuction ====================

    function test_getAuction_returnsDefault() public view {
        IExecutionAuction.Auction memory a = auction.getAuction(9999);
        assertEq(a.workflowId, 0);
        assertEq(a.startBlock, 0);
        assertFalse(a.settled);
    }
}
