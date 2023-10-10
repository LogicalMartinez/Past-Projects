// SPDX-License-Identifier: MIT

// This is place to sell a large stake in a ERC20 Token

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/* 
///////////////////////
///// TO-DO LIST //////
///////////////////////

* DONE!

*/

pragma solidity ^0.8.18;

import {OracleLib, AggregatorV3Interface} from "./Libraries/OracleLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

///////////////
/// errors ////
///////////////
error TRANSFER_NOT_SUCCESSFUL();
error whitelistAddressesAndPriceFeedAddressesAmountsDontMatch();
error SWAP_NOT_SUCCESSFUL();

/// @title A Darkpool for Whales with a lot of WBTC
/// @author Christopher (logical) Martinez
/// @notice A user can deposit a large amount of WBTC and auction it for USDC
contract DarkPool {
    ////////////////////////
    /// Type Declartions ///
    ////////////////////////
    state public State;
    using OracleLib for AggregatorV3Interface;
    IERC20 private Token;
    mapping(address actioneer => mapping(address Token => uint256 reserveBalance))
        private auctioneerReserves;
    mapping(address owner => mapping(address Token => uint256 tokenAmount))
        private Token_Balance;
    mapping(address owner => uint256 bidAmount) private bids;
    mapping(address => auctionDetails) private auctions;
    mapping(address collateralToken => address priceFeed) private priceFeeds;
    address[] private whitelist;
    address[] private array_priceFeeds;
    struct auctionDetails {
        address _auctioneer;
        address _token;
        uint256 tokenAmount;
        uint256 USDC_price;
        uint256 _lowestBid;
    }

    ////////////////////////
    //// State Variables ///
    ////////////////////////
    address private constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // address private constant WBTC_USD_PRICE_FEED =
    //     0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c; // BTC / USD
    // address private constant USDC_USD_PRICE_FEED =
    //     0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address private auctioneer;
    address private highestBidder;
    uint256 private highestBid;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;

    /// @notice This determines the state of the auction
    enum state {
        CLOSED,
        OPEN
    }

    //////////////
    /// Events ///
    //////////////
    event deposited(address indexed _from, uint256 amount);
    event newHighestBidder(address indexed Bidder, uint256 amount);
    event sold(
        address indexed _buyer,
        address indexed auctioneer,
        uint256 WBTC_amount,
        uint256 USDC_amount
    );
    event newAuction(address indexed auctioneer, uint256 WBTC_amount);
    event changeofState(state State);

    //////////////////
    /// modifiers ///
    ////////////////
    modifier onlyAuctioneer() {
        require(msg.sender == auctioneer);
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice pushes the two allowed tokens to the whitelist
    constructor(
        address[] memory whitelistAddresses,
        address[] memory priceFeedsAddresses
    ) {
        // whitelist = whitelistAddresses;
        if (whitelistAddresses.length != priceFeedsAddresses.length) {
            revert whitelistAddressesAndPriceFeedAddressesAmountsDontMatch();
        }
        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            priceFeeds[whitelistAddresses[i]] = priceFeedsAddresses[i];
            array_priceFeeds.push(priceFeedsAddresses[i]);
            whitelist = [USDC, WBTC];
        }
    }

    ///////////////
    /// Receive ///
    ///////////////

    /// @notice This contract doesn't allow the use of a receive function
    receive() external payable {
        revert();
    }

    ////////////////////////
    /// Public Functions ///
    ////////////////////////

    /// @notice This function is used to deposit WBTC or USDC
    /// @param _token This is the Token address
    /// @param amount The amount of the Token you want to deposit
    function depositToken(address _token, uint256 amount) public {
        require(msg.sender != address(0));
        require(_token == WBTC || _token == USDC);
        // for (uint256 i = 0; i < whitelist.length; i++) {
        //     if (_token != whitelist[i]) {
        //         revert();
        //     }
        // }

        Token = IERC20(_token);
        address _from = msg.sender;

        Token_Balance[_from][_token] += amount;
        bool success = Token.transferFrom(_from, address(this), amount);
        if (!success) {
            revert TRANSFER_NOT_SUCCESSFUL();
        }
        emit deposited(_from, amount);
    }

    /// @notice Allows you to post an auction
    /// @param WBTCtokenAmount The amount of the WBTC you want to auction
    /// @param USDCPrice The price of the WBTC in USDC
    /// @param _lowestBid The lowest bid allowed on an auction
    function postAuction(
        uint256 WBTCtokenAmount,
        uint256 USDCPrice,
        uint256 _lowestBid
    ) public {
        auctioneer = msg.sender;
        require(auctioneer != address(0));
        require(State == state.CLOSED);
        require(Token_Balance[msg.sender][WBTC] >= WBTCtokenAmount);

        Token = IERC20(WBTC);
        auctionDetails storage details = auctions[auctioneer];

        Token_Balance[auctioneer][WBTC] -= WBTCtokenAmount;
        auctioneerReserves[auctioneer][WBTC] += WBTCtokenAmount;

        details._auctioneer = msg.sender;
        details._token = WBTC;
        details.tokenAmount = WBTCtokenAmount;
        details.USDC_price = USDCPrice;
        details._lowestBid = _lowestBid;
        highestBid = _lowestBid;

        State = state.OPEN;

        emit newAuction(auctioneer, WBTCtokenAmount);
        emit changeofState(state.OPEN);
    }

    /// @notice This allows a user interested to bid
    /// @param _amount The amount of USDC
    function bid(uint256 _amount) public {
        address _bidder = msg.sender;

        require(msg.sender != address(0));
        require(State == state.OPEN);
        require(_amount <= Token_Balance[_bidder][USDC]);
        require(_amount >= auctions[auctioneer]._lowestBid);
        require(_amount > highestBid);

        Token_Balance[_bidder][USDC] -= _amount;
        bids[_bidder] += _amount;

        highestBid = _amount;
        highestBidder = msg.sender;

        emit newHighestBidder(_bidder, _amount);
    }

    /// @notice This function allows a user to buy the tokens at the price posted by the auctioneer
    function buy() public {
        auctionDetails storage details = auctions[auctioneer];
        address buyer = msg.sender;
        uint256 USDCamount = auctions[auctioneer].USDC_price;
        uint256 auctionAmount = details.tokenAmount;

        require(buyer != address(0));
        require(State == state.OPEN);
        require(USDCamount <= Token_Balance[buyer][USDC]);

        Token_Balance[buyer][USDC] -= USDCamount;
        auctioneerReserves[auctioneer][WBTC] -= auctionAmount;
        Token_Balance[auctioneer][USDC] += USDCamount;
        Token_Balance[buyer][WBTC] += auctionAmount;

        State = state.CLOSED;

        bids[buyer] = 0;
        highestBid = 0;
        details._auctioneer = address(0);
        details._lowestBid = 0;
        details.tokenAmount = 0;
        details.USDC_price = 0;
        details._lowestBid = 0;

        emit changeofState(state.CLOSED);
        emit sold(buyer, auctioneer, USDCamount, auctionAmount);
    }

    /// @notice This function allows the auctioneer to sell the tokens at the highest bid, to the highest bidder
    function approveBid() public onlyAuctioneer {
        auctionDetails storage details = auctions[auctioneer];
        uint256 USDCamount = highestBid;
        uint256 WBTCamount = details.tokenAmount;

        require(msg.sender != address(0));
        require(State == state.OPEN);

        auctioneerReserves[auctioneer][WBTC] -= WBTCamount;
        bids[highestBidder] -= USDCamount;
        Token_Balance[auctioneer][USDC] += USDCamount;
        Token_Balance[highestBidder][WBTC] += WBTCamount;

        State = state.CLOSED;

        bids[highestBidder] = 0;
        highestBid = 0;
        details._auctioneer = address(0);
        details._lowestBid = 0;
        details.tokenAmount = 0;
        details.USDC_price = 0;
        details._lowestBid = 0;

        emit sold(highestBidder, auctioneer, USDCamount, WBTCamount);
        emit changeofState(state.CLOSED);
    }

    /// @notice This function is used to cancel the auction
    function cancelAuction() public onlyAuctioneer {
        auctionDetails storage details = auctions[auctioneer];
        require(msg.sender != address(0));
        require(State == state.OPEN);

        uint256 amount = details.tokenAmount;

        auctioneerReserves[auctioneer][WBTC] -= amount;
        Token_Balance[auctioneer][WBTC] += amount;

        State = state.CLOSED;

        bids[highestBidder] = 0;
        highestBid = 0;
        details._auctioneer = address(0);
        details._lowestBid = 0;
        details.tokenAmount = 0;
        details.USDC_price = 0;
        details._lowestBid = 0;

        highestBidder = address(0);

        emit changeofState(state.CLOSED);
    }

    /// @notice This function is used to tokens withdraw from this contract
    /// @param _token This is the token a user wants to withdraw
    /// @param amount This is the amount of the token a user wants to withdraw
    function withdraw(address _token, uint256 amount) public {
        require(msg.sender != address(0));
        require(Token_Balance[msg.sender][_token] >= amount);

        Token = IERC20(_token);
        address _to = msg.sender;

        Token_Balance[_to][_token] -= amount;

        Token.approve(address(this), amount);
        bool success = Token.transferFrom(address(this), _to, amount);
        if (!success) {
            revert TRANSFER_NOT_SUCCESSFUL();
        }
    }

    ///
    /// @param amount This is the amount of USDC a user wants to withdraw from the auction bid or is no longer the highest bidder and wants to withdraw his funds
    function withdrawAuctionBid(uint256 amount) public {
        address _bidder = msg.sender;
        require(_bidder != address(0));
        require(State == state.OPEN);
        require(amount == bids[_bidder]);

        bids[_bidder] -= amount;
        Token_Balance[_bidder][USDC] += amount;
    }

    ///////////////////////////////////////
    //// Private View & Pure functions ////
    ///////////////////////////////////////
    function _getUsdValue(
        address token,
        uint256 amount
    ) private view returns (uint256) {
        address _priceFeed = priceFeeds[token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        (, int256 price, , , ) = priceFeed.staleCheckLatestRoundData();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return
            ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    //////////////////////////////////////////////////
    //// External & Public View & Pure functions ////
    ////////////////////////////////////////////////

    /// @return Returns the current price
    function currentUSDCPrice() external view returns (uint256) {
        auctionDetails storage details = auctions[auctioneer];
        return details.USDC_price;
    }

    /// @return Returns the auctioneer
    function seeAuctioneer() external view returns (address) {
        auctionDetails storage details = auctions[auctioneer];
        return details._auctioneer;
    }

    /// @return Returns the top bid
    function seeTopBid() external view returns (uint256) {
        return highestBid;
    }

    /// @return Returns the highest bidder
    function seeTopBidder() external view returns (address) {
        return highestBidder;
    }

    /// @return Returns the amount WBTC
    function seeAmountofAuctionedWBTC() external view returns (uint256) {
        auctionDetails storage details = auctions[auctioneer];
        return details.tokenAmount;
    }
    /// @return Returns the balance for the user and the selected token
    function seeTokenBalance(
        address userAddress,
        address _token
    ) public view returns (uint256) {
        return Token_Balance[userAddress][_token];
    }

    /// @return Returns the token type on the bid
    function seeAuctionedToken() external view returns (address) {
        auctionDetails storage details = auctions[auctioneer];
        return details._token;
    }
    /// @return Returns the price of the token inputted
    function getUsdValue(
        address _token,
        uint256 amount // in WEI
    ) external view returns (uint256) {
        return _getUsdValue(_token, amount);
    }

    /// @return Returns the token type on the bid
    function seeAuctionState() external view returns (state) {
        return State;
    }

    /// @return Returns your bid
    function seeYourBids(address bidder) external view returns (uint256) {
        return bids[bidder];
    }

    /// @return Returns auctioneer reserves
    function seeAuctioneerReserves(
        address _auctioneer
    ) external view returns (uint256) {
        return auctioneerReserves[_auctioneer][WBTC];
    }
}
