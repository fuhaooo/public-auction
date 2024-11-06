// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Auction {
    address public creator;
    uint256 public commission;
    uint256 public lotCount;
    uint256 public auctionRound;
    bool public auctionOngoing;
    uint256 public startTime;
    uint256 public endTime;
    bool public ended;
    uint256 private constant MAX_EXTENSIONS = 2;

    bool private locked = false;

    struct Lot {
        uint256 id;
        address seller;
        address maxPriceBidder;
        uint256 reservePrice;
        uint256 maxPrice;
        string desc;
        uint256 roundEndTime;
        bool ended;
        uint256 extensionCount;
    }

    mapping(uint256 => Lot) public catalogue;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;

    event CreateAuction(address creator, uint256 commission, uint256 startTime);
    event ListedForSale(address seller, uint256 id, uint256 reservePrice);
    event StartFirstRound(uint256 auctionRound, uint256 roundEndTime);
    event StartNewRound(uint256 auctionRound, uint256 roundEndTime);
    event MaxPriceIncreased(
        uint256 auctionRound,
        address maxPriceBidder,
        uint256 maxPrice
    );
    event EndRound(
        uint256 auctionRound,
        address maxPriceBidder,
        uint256 maxPrice
    );
    event EndAuction(address creator, uint256 endTime);
    event PendingRefund(address bidder, uint256 amount);

    constructor() payable {}

    modifier noReentrancy() {
        require(!locked, "No reentrancy allowed");
        locked = true;
        _;
        locked = false;
    }

    function createAuction(uint256 _commission) external {
        require(_commission >= 0, "commission must be >= 0");

        creator = msg.sender;
        commission = _commission;
        ended = false;
        lotCount = 0;
        auctionRound = 0;
        auctionOngoing = false;

        emit CreateAuction(msg.sender, _commission, block.timestamp);
    }

    function listedForSale(
        uint256 _reservePrice,
        string memory _desc
    ) external {
        require(creator != msg.sender, "creator cannot list for sale");
        require(
            _reservePrice > commission,
            "reserve price needs to be > commission"
        );
        require(ended != true, "the auction has ended");

        uint256 oldNum = lotCount;
        catalogue[lotCount] = Lot({
            id: lotCount,
            seller: msg.sender,
            maxPriceBidder: address(0),
            reservePrice: _reservePrice,
            maxPrice: 0,
            desc: _desc,
            roundEndTime: 0,
            ended: false,
            extensionCount: 0
        });
        lotCount++;
        emit ListedForSale(msg.sender, oldNum, _reservePrice);
    }

    function startFirstRound(uint256 _biddingTime) external {
        require(
            msg.sender == creator,
            "only the auction creator can start the auction"
        );
        require(
            auctionRound == 0 && !auctionOngoing,
            "auction already started"
        );

        auctionOngoing = true;
        uint256 roundEndTime = block.timestamp + _biddingTime;
        catalogue[auctionRound].roundEndTime = roundEndTime;
        catalogue[auctionRound].ended = false;

        emit StartFirstRound(auctionRound, roundEndTime);
    }

    function startNewRound(uint256 _biddingTime) external {
        require(
            msg.sender == creator,
            "only the auction creator can start a new round"
        );
        require(auctionRound < lotCount, "no more lots available");
        require(auctionOngoing == false, "previous round is not finished");

        auctionOngoing = true;
        uint256 roundEndTime = block.timestamp + _biddingTime;
        auctionRound++;
        catalogue[auctionRound].roundEndTime = roundEndTime;
        catalogue[auctionRound].ended = false;

        emit StartNewRound(auctionRound, roundEndTime);
    }

    function bid() public payable {
        Lot storage currentLot = catalogue[auctionRound];
        require(!currentLot.ended, "auction round already ended");
        require(
            msg.value >= currentLot.reservePrice,
            "bid need >= reserve price"
        );
        require(msg.value > currentLot.maxPrice, "bid need > max price");

        if (currentLot.maxPriceBidder != address(0)) {
            pendingReturns[auctionRound][
                currentLot.maxPriceBidder
            ] += currentLot.maxPrice;
        }

        uint256 currentTime = block.timestamp;
        if (
            currentTime <= currentLot.roundEndTime &&
            currentTime >= (currentLot.roundEndTime - 3 minutes) &&
            currentLot.extensionCount < MAX_EXTENSIONS
        ) {
            catalogue[auctionRound].roundEndTime += 3 minutes;
            currentLot.extensionCount++;
        }

        currentLot.maxPriceBidder = msg.sender;
        currentLot.maxPrice = msg.value;
        emit MaxPriceIncreased(auctionRound, msg.sender, msg.value);
    }

    function withdraw() public noReentrancy {
        uint256 amount = pendingReturns[auctionRound][msg.sender];
        require(amount > 0, "no fund to withdraw");
        pendingReturns[auctionRound][msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function endRound() public {
        require(
            msg.sender == creator,
            "only auction creator can start new auction round"
        );
        Lot storage currentLot = catalogue[auctionRound];
        require(!currentLot.ended, "Auction has already been ended.");
        currentLot.ended = true;
        auctionOngoing = false;
        emit EndRound(
            auctionRound,
            currentLot.maxPriceBidder,
            currentLot.maxPrice
        );

        // First transfer to the seller
        (bool sentToSeller, ) = payable(currentLot.seller).call{
            value: currentLot.maxPrice - commission
        }("");
        require(sentToSeller, "Failed to send funds to seller");

        // Then transfer to the creator
        (bool sentToCreator, ) = payable(creator).call{value: commission}("");
        require(sentToCreator, "Failed to send commission to creator");

        // If it's the last lot, end the auction
        if (lotCount == auctionRound) {
            ended = true;
            endTime = block.timestamp;
            emit EndAuction(msg.sender, endTime);
        }
    }

    function getAllLots() external view returns (Lot[] memory) {
        Lot[] memory lots = new Lot[](lotCount);
        for (uint256 i = 0; i < lotCount; i++) {
            lots[i] = catalogue[i];
        }
        return lots;
    }

    function getCurrentLotDetails() external view returns (Lot memory) {
        require(auctionRound < lotCount, "No lots available for current round");
        return catalogue[auctionRound];
    }
}
