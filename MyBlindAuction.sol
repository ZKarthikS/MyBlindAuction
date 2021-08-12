pragma solidity >0.4.23 <0.7.0;

contract MyBlindAuction{
    
    uint public HashedBiddingEnd; //Will explain what Hashed Bidding means later down the code.
    uint public FinalBiddingEnd;
    address payable public beneficiary;
    //address public Auctioneer;
    bool public ended;
    
    struct Bid{
        bytes32 HashedBid;
        uint BidAmount;
    }
    
    mapping(address => Bid) bids; 
    mapping(address => uint) PendingReturnAmount;
    mapping(address => bool) BidAlreadyExists; //To ensure that each person is entitled to only one bid.
    
    address HighestBidder;
    uint HighestBidAmount;
    
    constructor (uint hashedbiddingTime, uint Finalbiddingtime, address payable _beneficiary) public {
        HashedBiddingEnd = now + hashedbiddingTime;
        FinalBiddingEnd = HashedBiddingEnd + Finalbiddingtime;
        beneficiary = _beneficiary;
    }
    
    modifier onlyBefore(uint time){
        require(now<=time);
        _;
    }
    modifier onlyAfter(uint time){
        require(now>time);
        _;
    }
    modifier CanPlaceBid(address sender){
        require(!BidAlreadyExists[sender]);
        _;
    }
    
    /*I have two functions here: GenerateHashedBid and PlaceBid.
    Both of these functions have two different time periods and time limits.
    The first function herre is used to generate a hashed bid (an undisclosed type of bid)
    Each of these hashed bids contain both the person who has created the hash bid and the amount they would like to bid.
    This function can be invoked more than once as long as the time is not exceeded.
    Although multiple hashed bids can be created, only the final one will be taken into consideration.
    The output of this function called the hashed bid needs to be kept safely as it will be used in the next function.
    */
    function GenerateHashedBid(uint _amount) public onlyBefore(HashedBiddingEnd) returns(bytes32){
        require(msg.sender.balance >= _amount);
        bids[msg.sender].BidAmount = _amount;
        bids[msg.sender].HashedBid = (keccak256(abi.encodePacked(_amount, msg.sender)));
        return(bids[msg.sender].HashedBid);
    }
    
    /*This second function takes in the hashed bid from the previous one. 
    It requires the same person to use the function and 
    one has to make sure the value of the message is same as the bid amount. 
    This has a different time period from the previous one and can't be invoked immediately.
    */
    function PlaceBid(bytes32 _HashedBid) public payable onlyBefore(FinalBiddingEnd) onlyAfter(HashedBiddingEnd) CanPlaceBid(msg.sender){
        require(_HashedBid == keccak256(abi.encodePacked(bids[msg.sender].BidAmount, msg.sender)));
        require(msg.value == bids[msg.sender].BidAmount * (1 ether));
        BidAlreadyExists[msg.sender] = true;
        if(msg.value<=HighestBidAmount){
            PendingReturnAmount[msg.sender] = msg.value;
            return;
        }
        if(HighestBidder != address(0)){
            PendingReturnAmount[HighestBidder] = HighestBidAmount;
        }
        HighestBidAmount = msg.value;
        HighestBidder = msg.sender;
    }
    
    //This function is to end the final auction and is kept public.
    //It ensures that the beneficiary receives the required amount.
    //I have a commented a line which would require only the "Auctioneer" to access this function.
    function EndAuction() public onlyAfter(FinalBiddingEnd) {
        //require(msg.sender == Auctioneer);
        require(!ended);
        ended = true;
        beneficiary.transfer(HighestBidAmount);
    }
    
    //Self explanaory - used to withdraw funds that are outbidded.
    //Can be called multiple times by the same person but only once is the amount transferred.
    function Withdraw() public onlyAfter(FinalBiddingEnd) {
        require(ended);
        uint WithdrawAmount = PendingReturnAmount[msg.sender];
        PendingReturnAmount[msg.sender] = 0;
        msg.sender.transfer(WithdrawAmount);
    }
    
    //Just to see if the person is outbidded and has some money to withdraw
    function ViewPendingReturns() external view onlyAfter(HashedBiddingEnd) returns(uint) {
        require(BidAlreadyExists[msg.sender]);
        return PendingReturnAmount[msg.sender];
    }
    
}

//The code when tested on my system worked fine. Hope it's the same on the other side too.
