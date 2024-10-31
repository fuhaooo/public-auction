// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Auction.sol";

contract AuctionTest is Test {
    Auction auction;
    address creator;
    address seller;
    address bidder1;
    address bidder2;

    function setUp() public {
        auction = new Auction();
        creator = address(this);
        seller = address(0x1);
        bidder1 = address(0x2);
        bidder2 = address(0x3);
    }

    function testCreateAuction() public {
        auction.createAuction(0.1 ether, block.timestamp + 1 hours);
        assertEq(auction.creator(), creator);
        assertEq(auction.commission(), 0.1 ether);
        assertTrue(auction.startTime() > block.timestamp);
        assertEq(auction.lotCount(), 0);
        assertFalse(auction.ended());
    }

    function testListedForSale() public {
        auction.createAuction(0.1 ether, block.timestamp + 1 hours);
        vm.prank(seller);
        auction.listedForSale(0.2 ether, "Test Lot");

        (
            uint256 id,
            address sellerAddr,
            address maxBidder,
            uint256 reservePrice,
            uint256 maxPrice,
            string memory desc,
            uint256 roundEndTime,
            bool ended,
            uint256 extensionCount
        ) = auction.catalogue(0);

        // 进行断言
        assertEq(id, 0);
        assertEq(sellerAddr, seller);
        assertEq(reservePrice, 0.2 ether);
        assertFalse(ended);
        assertEq(auction.lotCount(), 1);
    }

    function testStartNewRound() public {
        auction.createAuction(0.1 ether, block.timestamp + 1 hours);
        vm.prank(seller);
        auction.listedForSale(0.2 ether, "Test Lot");

        vm.warp(block.timestamp + 1 hours);
        vm.prank(creator);

        // 检查 lotCount 是否正确增加
        assertEq(
            auction.lotCount(),
            1,
            "Lot count should be 1 after listing for sale"
        );

        auction.startNewRound(10 minutes);

        // 检查轮次状态
        assertTrue(auction.auctionOngoing());

        (
            uint256 id,
            address sellerAddr,
            address maxBidder,
            uint256 reservePrice,
            uint256 maxPrice,
            string memory desc,
            uint256 roundEndTime,
            bool ended,
            uint256 extensionCount
        ) = auction.catalogue(0);

        assertTrue(roundEndTime > block.timestamp);
    }

    function testBid() public {
        auction.createAuction(0.1 ether, block.timestamp + 1 hours);
        vm.prank(seller);
        auction.listedForSale(0.2 ether, "Test Lot");

        vm.warp(block.timestamp + 1 hours);
        vm.prank(creator);
        auction.startNewRound(10 minutes);

        vm.deal(bidder1, 0.5 ether);
        vm.prank(bidder1);
        auction.bid{value: 0.3 ether}();

        (
            uint256 id,
            address sellerAddr,
            address maxBidder,
            uint256 reservePrice,
            uint256 maxPrice,
            string memory desc,
            uint256 roundEndTime,
            bool ended,
            uint256 extensionCount
        ) = auction.catalogue(0);
        assertEq(maxBidder, bidder1, "Max bidder should be bidder1");
        assertEq(maxPrice, 0.3 ether, "Max price should be 0.3 ether");
    }

    function testWithdraw() public {
        auction.createAuction(0.1 ether, block.timestamp + 1 hours);
        vm.prank(seller);
        auction.listedForSale(0.2 ether, "Test Lot");

        vm.warp(block.timestamp + 1 hours);
        vm.prank(creator);
        auction.startNewRound(10 minutes);

        // 添加资金给竞标者
        vm.deal(bidder1, 0.5 ether);
        vm.prank(bidder1);
        auction.bid{value: 0.3 ether}();

        vm.prank(creator);
        auction.endRound();

        uint256 withdrawAmount = auction.pendingReturns(0, bidder1);
        assertEq(withdrawAmount, 0, "Withdraw amount should be zero");

        vm.prank(bidder1);
        auction.withdraw();
    }

    function testEndAuction() public {
        auction.createAuction(0.1 ether, block.timestamp + 1 hours);
        vm.prank(seller);
        auction.listedForSale(0.2 ether, "Test Lot");

        vm.warp(block.timestamp + 1 hours);
        vm.prank(creator);
        auction.startNewRound(10 minutes);

        vm.deal(bidder1, 0.5 ether);
        vm.prank(bidder1);
        auction.bid{value: 0.3 ether}();

        vm.prank(creator);
        auction.endRound();

        assertTrue(auction.ended(), "Auction should be ended");
        assertTrue(auction.endTime() > 0, "End time should be set");
    }
}
