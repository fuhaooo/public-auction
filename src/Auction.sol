//SPDX-License-Identifier: MIT
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
    event StartNewRound(uint256 auctionRound, uint256 roundEndTime);
    event MaxPriceIncreased(uint256 auctionRound, address maxPriceBidder, uint256 maxPrice);
    event EndRound(uint256 auctionRound, address maxPriceBidder, uint256 maxPrice);
    event EndAuction(address creator, uint256 endTime);

    function createAuction(uint256 _commission, uint256 _startTime) external {
        require(_commission >= 0,"commission need >= 0");
        require(_startTime >= block.timestamp + 30 minutes, "start time need to be in at least 30 minutes later");
        creator = msg.sender;
        commission = _commission;
        startTime = _startTime;
        ended = false;
        lotCount = 0;
        auctionRound = 0;
        auctionOngoing = false;
        emit CreateAuction(msg.sender, _commission, _startTime);
    }

    function listedForSale(uint256 _reservePrice, string memory _desc) external {
        require(block.timestamp < startTime, "the auction is beginning");
        require(creator != msg.sender, "creator can not listed for sale");
        require(_reservePrice > commission, "reserve price need > commission");
        require(ended != true, "the auction is ended");
       
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

    function startNewRound(uint256 _biddingTime) external {
        require(block.timestamp >= startTime, "the auction is not begin");
        require(catalogue[auctionRound].ended, "don't have a lot");
        require(msg.sender == creator, "only auction creator can start new auction round");
        require(auctionOngoing, "the previous round is not finish");

        auctionOngoing = true;
        uint256 roundEndTime = block.timestamp + _biddingTime;
        catalogue[auctionRound].roundEndTime = roundEndTime;

        emit StartNewRound(auctionRound, roundEndTime);
        auctionRound++;
    }

    function bid() public payable{
        Lot storage currentLot = catalogue[auctionRound];
        require(true == currentLot.ended, "auction round already ended");
        require(msg.value >= currentLot.reservePrice, "bid need >= reserve price");
        require(msg.value > currentLot.maxPrice, "bid need > max price");
        
        if(currentLot.maxPriceBidder != address(0)) {
            pendingReturns[auctionRound][msg.sender] += msg.value;
        }

        uint256 currentTime = block.timestamp;
        if (currentTime <= currentLot.roundEndTime && currentTime >= (currentLot.roundEndTime - 3 minutes) && currentLot.extensionCount < MAX_EXTENSIONS) {
            catalogue[auctionRound].roundEndTime += 3;
            currentLot.extensionCount++;
        }

        currentLot.maxPriceBidder = msg.sender;
        currentLot.maxPrice = msg.value;
        emit MaxPriceIncreased(auctionRound, msg.sender, msg.value);
    }

    function withdraw() public {
        uint amount = pendingReturns[auctionRound][msg.sender];
        require(amount > 0,"no fund to withdraw");
        pendingReturns[auctionRound][msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function endRound() public {
        require(msg.sender == creator, "only auction creator can start new auction round");
        Lot storage currentLot = catalogue[auctionRound];
        require(!currentLot.ended, "Auction has already been ended.");
        currentLot.ended = true;
        auctionOngoing = false;
        emit EndRound(auctionRound, currentLot.maxPriceBidder, currentLot.maxPrice);
        payable(currentLot.seller).transfer(currentLot.maxPrice - commission);
        payable(creator).transfer(commission);
        if(lotCount == auctionRound) {
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
        require(auctionRound >= 0, "No lots available for current round");
        return catalogue[auctionRound];
    }


}