// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Auction.sol";

contract AuctionTest is Test {
    Auction public auction;
    address public creator = address(0xABCD);
    address public seller = address(0xBEEF);
    address public bidder1 = address(0xCAFE);
    address public bidder2 = address(0xDEAD);

    function setUp() public {
        vm.startPrank(creator);
        auction = new Auction();
        auction.createAuction(1 ether); // 设置佣金为1 ether
        vm.stopPrank();
    }

    function testCreateAuction() public {
        assertEq(auction.creator(), creator);
        assertEq(auction.commission(), 1 ether);
        assertEq(auction.ended(), false);
    }

    function testListForSale() public {
        vm.startPrank(seller);
        auction.listedForSale(2 ether, "Lot #1");
        vm.stopPrank();

        (uint256 id, address lotSeller, , uint256 reservePrice, , string memory desc, , , ) = auction.catalogue(0);
        assertEq(id, 0);
        assertEq(lotSeller, seller);
        assertEq(reservePrice, 2 ether);
        assertEq(desc, "Lot #1");
    }

    function testStartFirstRound() public {
        testListForSale();
        
        vm.startPrank(creator);
        auction.startFirstRound(1 hours);
        vm.stopPrank();
        
        (, , , , , , uint256 roundEndTime, bool ended, ) = auction.catalogue(0);
        assertEq(auction.auctionRound(), 0);
        assertEq(auction.auctionOngoing(), true);
        assertEq(ended, false);
        assertGt(roundEndTime, block.timestamp);
    }

    function testBid() public {
        testStartFirstRound();

        vm.deal(bidder1, 3 ether);
        vm.startPrank(bidder1);
        auction.bid{value: 3 ether}();
        vm.stopPrank();

        (, , address maxPriceBidder, , uint256 maxPrice, , , , ) = auction.catalogue(0);
        assertEq(maxPriceBidder, bidder1);
        assertEq(maxPrice, 3 ether);
    }

    function testEndRound() public {
        testBid();

        vm.deal(bidder2, 4 ether);
        vm.startPrank(bidder2);
        auction.bid{value: 4 ether}();
        vm.stopPrank();

        // End round and verify funds distribution
        vm.startPrank(creator);
        auction.endRound();
        vm.stopPrank();

        (, , , , , , , bool ended, ) = auction.catalogue(0);
        assertEq(ended, true);
        assertEq(auction.auctionOngoing(), false);

        uint256 sellerBalance = address(seller).balance;
        uint256 creatorBalance = address(creator).balance;
        assertEq(sellerBalance, 3 ether); // 确认卖家收到扣除佣金的最高出价
        assertEq(creatorBalance, 1 ether); // 确认拍卖创建者收到佣金
    }

    function testWithdraw() public {
        testBid();

        vm.deal(bidder2, 5 ether);
        vm.startPrank(bidder2);
        auction.bid{value: 5 ether}();
        vm.stopPrank();

        // Ensure that bidder1 can withdraw funds
        uint256 initialBalance = bidder1.balance;

        vm.startPrank(bidder1);
        auction.withdraw();
        vm.stopPrank();

        assertEq(bidder1.balance, initialBalance + 3 ether);
    }
}
