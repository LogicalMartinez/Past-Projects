// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DarkPool} from "../src/DarkPool.sol";
import {DeployDarkPool} from "../script/DeployDarkPool.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Test, console} from "../lib/forge-std/src/Test.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {OracleLib} from "../src/Libraries/OracleLib.sol";
import {StdCheats} from "../lib/forge-std/src/Test.sol";

contract DarkPoolTest is StdCheats, Test {
    uint256 auctioneerPrivatekey = 123;
    uint256 userPrivatekey = 1234;
    address private auctioneer = vm.addr(auctioneerPrivatekey);
    address private bidder = vm.addr(userPrivatekey);
    address buyer = address(123);
    address private highestBidder;
    uint256 private highestBid;
    uint256 public constant STARING_BALANCE = 12 ether;
    uint256 public constant WBTC_STARTING_AMOUNT = 5 * 1e8;
    uint256 public constant WBTC_AUCTION_AMOUNT = 3 * 1e8;
    uint256 public constant USDC_STARTING_AMOUNT = 1000 * 1e6;
    uint256 public constant USDC_AUCTION_BUY_PRICE = 100 * 1e6;
    uint256 public constant USDC_LOWEST_BID = 60 * 1e6;
    uint256 public constant USDC_NEW_HIGHEST_BID = 90 * 1e6;

    state public State;

    address WBTCUsdPriceFeed;
    address USDCUsdPriceFeed;
    address USDC;
    address WBTC;
    IERC20 public _WBTC;
    IERC20 public _USDC;
    uint256 deployerKey; //= vm.envUint("PRIVATE_KEY");

    DarkPool public darkPool;
    HelperConfig public helperConfig;
    auctionDetails public details;

    struct auctionDetails {
        address _auctioneer;
        address _token;
        uint256 tokenAmount;
        uint256 USDC_price;
        uint256 _lowestBid;
    }

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

    function setUp() external {
        DeployDarkPool deployer = new DeployDarkPool();
        (darkPool, helperConfig) = deployer.run();

        (
            WBTCUsdPriceFeed,
            USDCUsdPriceFeed,
            USDC,
            WBTC,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

        whitelist = [USDC, WBTC];
        priceFeeds = [USDCUsdPriceFeed, WBTCUsdPriceFeed];

        _WBTC = IERC20(WBTC);
        _USDC = IERC20(USDC);

        (darkPool, helperConfig) = deployer.run();
    }

    modifier auctioneerDepositandpostAuction() {
        deal(address(_WBTC), auctioneer, WBTC_STARTING_AMOUNT, true);

        vm.startPrank(auctioneer);
        _WBTC.approve(address(darkPool), WBTC_STARTING_AMOUNT);
        darkPool.depositToken(WBTC, WBTC_STARTING_AMOUNT);
        darkPool.postAuction(
            WBTC_AUCTION_AMOUNT,
            USDC_AUCTION_BUY_PRICE,
            USDC_LOWEST_BID
        );
        vm.stopPrank();
        _;
    }

    modifier bidderDepositandBid() {
        deal(address(_USDC), bidder, USDC_STARTING_AMOUNT, true);

        vm.startPrank(bidder);
        _USDC.approve(address(darkPool), USDC_STARTING_AMOUNT);
        darkPool.depositToken(USDC, USDC_STARTING_AMOUNT);
        darkPool.bid(USDC_NEW_HIGHEST_BID);
        vm.stopPrank();
        _;
    }

    /////////////////////////
    /// Constructor test ///
    ///////////////////////

    address[] public whitelist;
    address[] public priceFeeds;

    function testIfArrayLengthIsNotEqual() external {
        address badToken;

        whitelist.push(badToken);

        vm.expectRevert();
        new DarkPool(whitelist, priceFeeds);
    }

    ///////////////////////
    /// function tests ///
    /////////////////////

    function testDepositWBTC() public {
        // Arrange
        deal(address(_WBTC), auctioneer, WBTC_STARTING_AMOUNT, true);

        // Act
        vm.startPrank(auctioneer);
        _WBTC.approve(address(darkPool), WBTC_STARTING_AMOUNT);
        darkPool.depositToken(WBTC, WBTC_STARTING_AMOUNT);
        vm.stopPrank();

        uint256 auctioneerBalance = darkPool.seeTokenBalance(auctioneer, WBTC);

        // Assert
        assertEq(auctioneerBalance, WBTC_STARTING_AMOUNT);

        console.log(auctioneerBalance, "auctioneer's balance");
    }

    function testDepositUSDC() public {
        deal(address(_USDC), bidder, USDC_STARTING_AMOUNT, true);

        vm.startPrank(bidder);
        _USDC.approve(address(darkPool), USDC_STARTING_AMOUNT);
        darkPool.depositToken(USDC, USDC_STARTING_AMOUNT);
        vm.stopPrank();

        uint256 aliceBalance = darkPool.seeTokenBalance(bidder, USDC);

        assertEq(aliceBalance, USDC_STARTING_AMOUNT);

        console.log(aliceBalance, "alice's balance");
    }

    function testPostAuction() public auctioneerDepositandpostAuction {
        /* Check struct details */
        uint256 balance = darkPool.seeTokenBalance(auctioneer, WBTC);
        uint256 WBTCAuctionedAmount = darkPool.seeAmountofAuctionedWBTC();
        uint256 newBalance = WBTC_STARTING_AMOUNT - WBTC_AUCTION_AMOUNT;
        uint256 auctioneerReserveBalance = darkPool.seeAuctioneerReserves(
            auctioneer
        );

        assertEq(auctioneerReserveBalance, WBTC_AUCTION_AMOUNT);
        assertEq(WBTCAuctionedAmount, WBTC_AUCTION_AMOUNT);
        assertEq(balance, newBalance);

        console.log(auctioneerReserveBalance, "Autioneer Reserve balance");
        console.log(WBTCAuctionedAmount, "Price");
        console.log(balance, "Balance");
    }

    function testbid()
        external
        auctioneerDepositandpostAuction
        bidderDepositandBid
    {
        uint256 _seeTopBid = darkPool.seeTopBid();
        address topBidder = darkPool.seeTopBidder();
        uint256 _bids = darkPool.seeYourBids(bidder);
        address gay = darkPool.priceFeeds(WBTC);

        assertEq(_seeTopBid, USDC_NEW_HIGHEST_BID);
        assertEq(bidder, topBidder);
        assertEq(_bids, USDC_NEW_HIGHEST_BID);

        console.log(_seeTopBid, "Top bid");
        console.log(gay, "sdavkasnvmdsavdndvlsavklvas");
    }

    function testBuy() external auctioneerDepositandpostAuction {
        deal(address(_USDC), buyer, USDC_STARTING_AMOUNT);

        // Buyer Has deposited tokens and is buying the WBTC
        vm.startPrank(buyer);
        _USDC.approve(address(darkPool), USDC_STARTING_AMOUNT);
        darkPool.depositToken(USDC, USDC_STARTING_AMOUNT);
        darkPool.buy();
        vm.stopPrank();

        uint256 buyerUSDCBalance = darkPool.seeTokenBalance(buyer, USDC);
        uint256 buyerWBTCBalance = darkPool.seeTokenBalance(buyer, WBTC);
        uint256 auctioneerWBTCBalance = darkPool.seeTokenBalance(
            auctioneer,
            WBTC
        );
        uint256 auctioneerUSDCBalance = darkPool.seeTokenBalance(
            auctioneer,
            USDC
        );
        uint256 _seeYourBids = darkPool.seeYourBids(bidder);
        uint256 userBids = darkPool.seeYourBids(bidder);
        uint256 auctioneerReserveBalance = darkPool.seeAuctioneerReserves(
            auctioneer
        );
        uint256 expectedBalance = 0;
        uint256 expectedBidAmount = 0;

        assertEq(auctioneerReserveBalance, expectedBalance);
        assertEq(_seeYourBids, expectedBidAmount);
        assertEq(auctioneerUSDCBalance, USDC_AUCTION_BUY_PRICE);
        assertEq(buyerWBTCBalance, WBTC_AUCTION_AMOUNT);
        assertEq(userBids, expectedBidAmount);

        console.log(buyerUSDCBalance, "This is the buyer's USDC balance");
        console.log(buyerWBTCBalance, "This is the buyer's WBTC balance");
        console.log(
            auctioneerWBTCBalance,
            "This is the auctioneer's WBTC balance"
        );
        console.log(
            auctioneerUSDCBalance,
            "This is the auctioneer's USDC balance"
        );
        console.log(
            auctioneerReserveBalance,
            "Actioneer Reserve balance after buyer has bought"
        );
    }

    function testApproveBid()
        external
        auctioneerDepositandpostAuction
        bidderDepositandBid
    {
        vm.prank(auctioneer);
        darkPool.approveBid();

        uint256 bidderUSDCBalance = darkPool.seeTokenBalance(bidder, USDC);
        uint256 bidderWBTCBalance = darkPool.seeTokenBalance(bidder, WBTC);
        uint256 auctioneerWBTCBalance = darkPool.seeTokenBalance(
            auctioneer,
            WBTC
        );
        uint256 auctioneerUSDCBalance = darkPool.seeTokenBalance(
            auctioneer,
            USDC
        );

        uint256 userBids = darkPool.seeYourBids(bidder);
        uint256 auctioneerReserveBalance = darkPool.seeAuctioneerReserves(
            auctioneer
        );
        uint256 expectedBalance = 0;
        uint256 expectedBidAmount = 0;

        assertEq(userBids, expectedBidAmount);
        assertEq(auctioneerReserveBalance, expectedBalance);
        assertEq(bidderWBTCBalance, WBTC_AUCTION_AMOUNT);
        assertEq(userBids, expectedBidAmount);
        assertEq(auctioneerUSDCBalance, USDC_NEW_HIGHEST_BID);

        console.log(bidderWBTCBalance, "This is the Bidder's WBTC balance");
        console.log(
            auctioneerWBTCBalance,
            "This is the auctioneer's WBTC balance"
        );
        console.log(
            auctioneerUSDCBalance,
            "This is the auctioneer's USDC balance"
        );
        console.log(
            auctioneerReserveBalance,
            "Actioneer Reserve balance after bid is aproved"
        );
    }

    function testCancelAuction() external auctioneerDepositandpostAuction {
        vm.startPrank(auctioneer);
        darkPool.cancelAuction();
        vm.stopPrank();

        uint256 auctioneerReserveBalance = darkPool.seeAuctioneerReserves(
            auctioneer
        );
        uint256 auctioneerBalance = darkPool.seeTokenBalance(auctioneer, WBTC);
        uint256 expectedBalance = 0;

        assertEq(auctioneerReserveBalance, expectedBalance);
        assertEq(auctioneerBalance, WBTC_STARTING_AMOUNT);

        console.log(
            auctioneerReserveBalance,
            "Auctioneer reserve balance after auction is canceled"
        );
        console.log(
            auctioneerBalance,
            "Auctioneer's balance after auction is canceled"
        );
    }

    function testWithdraw() external {
        deal(address(_WBTC), auctioneer, WBTC_STARTING_AMOUNT, true);

        vm.startPrank(auctioneer);
        console.log(
            _WBTC.balanceOf(address(darkPool)),
            "darkpool contract WBTC balance before withdrawal"
        );
        uint256 beforeAuctioneerBalance = darkPool.seeTokenBalance(
            auctioneer,
            WBTC
        );
        uint256 beforeAuctioneerWalletBalance = _WBTC.balanceOf(auctioneer);
        console.log(
            beforeAuctioneerBalance,
            "Auctioneer WBTC balance before withdrawal"
        );
        console.log(
            beforeAuctioneerWalletBalance,
            "auctioneer WBTC wallet balance before"
        );
        _WBTC.approve(address(darkPool), WBTC_STARTING_AMOUNT);
        darkPool.depositToken(WBTC, WBTC_STARTING_AMOUNT);
        darkPool.withdraw(WBTC, WBTC_STARTING_AMOUNT);
        vm.stopPrank();

        uint256 afterAuctioneerBalance = darkPool.seeTokenBalance(
            auctioneer,
            WBTC
        );

        uint256 afterAuctioneerWalletBalance = _WBTC.balanceOf(auctioneer);
        uint256 afterDarkPoolContractWBTCBalance = _WBTC.balanceOf(
            address(darkPool)
        );
        uint256 expectedBalance = 0;

        assertEq(afterAuctioneerBalance, expectedBalance);
        assertEq(afterAuctioneerWalletBalance, WBTC_STARTING_AMOUNT);
        assertEq(afterDarkPoolContractWBTCBalance, expectedBalance);

        console.log(
            afterAuctioneerBalance,
            "Auctioneer balance after withdrawal"
        );
        console.log(
            afterAuctioneerWalletBalance,
            "Auctioneer WBTC balance after withdrawal"
        );
        console.log(
            _WBTC.balanceOf(address(darkPool)),
            "darkpool contract WBTC balance after withdrawal"
        );
    }

    function testWithdrawAuctionBid()
        external
        auctioneerDepositandpostAuction
        bidderDepositandBid
    {
        vm.startPrank(bidder);
        darkPool.withdrawAuctionBid(USDC_NEW_HIGHEST_BID);
        vm.stopPrank();

        uint256 bidderUSDCBalance = darkPool.seeTokenBalance(bidder, USDC);
        uint256 userBids = darkPool.seeYourBids(bidder);
        uint256 expectedBidAmount = 0;

        assertEq(bidderUSDCBalance, USDC_STARTING_AMOUNT);
        assertEq(userBids, expectedBidAmount);

        console.log(
            bidderUSDCBalance,
            "Bidder USDC address after withdrwing from the bid"
        );
    }

    ///////////////////////////
    /// View Functions Test ///
    ///////////////////////////

    function testCurrentPrice() external auctioneerDepositandpostAuction {
        uint256 USDCPrice = darkPool.currentUSDCPrice();

        assertEq(USDCPrice, USDC_AUCTION_BUY_PRICE);

        console.log(USDCPrice, "Testing currentUSDCPrice view function ");
    }

    function testSeeAuctioneer() external auctioneerDepositandpostAuction {
        address seeAuctioneer = darkPool.seeAuctioneer();

        assertEq(seeAuctioneer, auctioneer);

        console.log(seeAuctioneer, "Testing seeAuctioneer view function");
    }

    function testseeTopBid()
        external
        auctioneerDepositandpostAuction
        bidderDepositandBid
    {
        uint256 TopBid = darkPool.seeTopBid();

        assertEq(TopBid, USDC_NEW_HIGHEST_BID);

        console.log(TopBid, "Testing seeTopBid view function");
    }

    function testseeTopBidder()
        external
        auctioneerDepositandpostAuction
        bidderDepositandBid
    {
        address topBidder = darkPool.seeTopBidder();

        assertEq(topBidder, bidder);

        console.log(topBidder, "Testing seetopbidder view function");
    }

    function testseeAmountofAuctionedWBTC()
        external
        auctioneerDepositandpostAuction
    {
        uint256 _WBTCAmountofAuctionedWBTC = darkPool
            .seeAmountofAuctionedWBTC();

        assertEq(_WBTCAmountofAuctionedWBTC, WBTC_AUCTION_AMOUNT);

        console.log(
            _WBTCAmountofAuctionedWBTC,
            "Testing seeAmountofAuctionedWBTC view function"
        );
    }

    function testseeTokenBalance() external {
        address user = address(123456);
        deal(address(_USDC), user, USDC_STARTING_AMOUNT, true);

        vm.startPrank(user);
        _USDC.approve(address(darkPool), USDC_STARTING_AMOUNT);
        darkPool.depositToken(USDC, USDC_STARTING_AMOUNT);
        vm.stopPrank();

        uint256 userBalance = darkPool.seeTokenBalance(user, USDC);

        assertEq(userBalance, USDC_STARTING_AMOUNT);

        console.log(userBalance, "Testing seeTokenBalance view function");
    }

    function testseeAuctionedToken() external auctioneerDepositandpostAuction {
        address auctionedToken = darkPool.seeAuctionedToken();

        assertEq(auctionedToken, WBTC);

        console.log(auctionedToken, "Tesing seeAuctionedToken view function");
    }

    //////////////////
    /// Price Test ///
    //////////////////

    function testGetUsdValue() external {
        uint256 WBTCAmountInWei = 1e18;
        uint256 tokenPrice = darkPool.getUsdValue(WBTC, WBTCAmountInWei);

        console.log(tokenPrice, "Testing getTokenPriceFromUsd view function");
    }
}
