// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";

import { IUniswapV2Router02, IUniswapV2Pair, IUniswapV2Router01, IWETH, IERC20 } from "../src/interfaces/Interfaces.sol";
import { IGogeERC20 } from "../src/extensions/IGogeERC20.sol";

import { DogeGaySon } from "../src/GogeToken.sol";
import { DogeGaySon1 } from "../src/TokenV1.sol";
import { GogeDAO } from "../src/GogeDao.sol";

contract MainDeploymentTesting is Utility, Test {
    DogeGaySon1 gogeToken_v1;
    DogeGaySon gogeToken_v2;

    address UNIV2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; //bsc

    function setUp() public {
        createActors();
        setUpTokens();

        // Deploy v1 token
        gogeToken_v1 = new DogeGaySon1();

        uint256 BNB_DEPOSIT = 300 ether;
        uint256 TOKEN_DEPOSIT = 22_310_409_737 ether;

        IWETH(WBNB).deposit{value: BNB_DEPOSIT}();

        // Approve TaxToken for UniswapV2Router.
        IERC20(address(gogeToken_v1)).approve(address(UNIV2_ROUTER), TOKEN_DEPOSIT);

        // Create liquidity pool.
        IUniswapV2Router01(UNIV2_ROUTER).addLiquidityETH{value: 220 ether}(
            address(gogeToken_v1),
            TOKEN_DEPOSIT,
            TOKEN_DEPOSIT,
            220 ether,
            address(this),
            block.timestamp + 300
        );

        // enable trading for v1
        gogeToken_v1.afterPreSale();
        gogeToken_v1.setTradingIsEnabled(true, 0);

        // Show price
        uint256 price = getPrice(address(gogeToken_v1));
        emit log_named_uint("cost of 1 v1 token", price); // 0.000003073904665581

        // Create holders of v1 token
        createHolders();

        // TODO: (1) Check dev address and router before deploying
        // TODO: (2) Deploy v2 token
        gogeToken_v2 = new DogeGaySon(
            address(0x4959bCED128E6F056A6ef959D80Bd1fCB7ba7A4B), // TODO: verify correct address
            address(0xe142E9FCbd9E29C4A65C4979348d76147190a05a), // TODO: verify correct address
            100_000_000_000,
            address(gogeToken_v1)
        );

        // TODO: (3) Disable trading on v1 to false
        gogeToken_v1.setTradingIsEnabled(false, 0);

        // TODO: (4) Exclude v2 from fees on v1
        gogeToken_v1.excludeFromFees(address(gogeToken_v2), true);

        // TODO: (5) Perform migration -> 6 days
        migrateActor(tim);
        migrateActor(joe);
        migrateActor(sal);
        migrateActor(nik);
        migrateActor(jon);

        // Show price of v2
        price = getPrice(address(gogeToken_v2));
        emit log_named_uint("cost of 1 v2 token", price); // 0.000002119865796663

        // TODO: (6) Perform mass airdrop to private sale contributors
        // NOTE: IF USING BULKSENDER -> MAKE SURE TO WHITELIST BULKSENDER CONTRACT
        gogeToken_v2.transfer(address(567), 20_000_000_000 ether);

        // TODO: (7) enableTrading() on v2
        gogeToken_v2.enableTrading();
    }

    // ~~ Utility Functions ~~

    /// @notice Returns the price of 1 token in USD
    function getPrice(address token) internal returns (uint256) {
        address[] memory path = new address[](3);

        path[0] = token;
        path[1] = WBNB;
        path[2] = BUSD;

        uint256[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(1 ether, path);

        return amounts[2];
    }

    /// @notice Creates v1 token holders. The holder balances should total just under 22B tokens
    function createHolders() internal {
        //Initialize wallet amounts.
        uint256 amountJoe = 10_056_322_590 ether;
        uint256 amountSal = 8_610_217_752 ether;
        uint256 amountNik = 900_261_463 ether;
        uint256 amountJon = 200_984_357 ether;
        uint256 amountTim = 600_000 ether;

        // Transfer tokens to Joe so he can migrate.
        gogeToken_v1.transfer(address(joe), amountJoe);
        gogeToken_v1.transfer(address(sal), amountSal);
        gogeToken_v1.transfer(address(nik), amountNik);
        gogeToken_v1.transfer(address(jon), amountJon);
        gogeToken_v1.transfer(address(tim), amountTim);

        // Verify amount v1 and 0 v2 tokens.
        assertEq(gogeToken_v1.balanceOf(address(joe)), amountJoe);
        assertEq(gogeToken_v1.balanceOf(address(sal)), amountSal);
        assertEq(gogeToken_v1.balanceOf(address(nik)), amountNik);
        assertEq(gogeToken_v1.balanceOf(address(jon)), amountJon);
        assertEq(gogeToken_v1.balanceOf(address(tim)), amountTim);
    }

    /// @notice migrate tokens from v1 to v2
    function migrateActor(Actor actor) internal {
        uint256 bal = gogeToken_v1.balanceOf(address(actor));

        // Approve and migrate
        assert(actor.try_approveToken(address(gogeToken_v1), address(gogeToken_v2), gogeToken_v1.balanceOf(address(actor))));
        assert(actor.try_migrate(address(gogeToken_v2)));

        assertEq(gogeToken_v1.balanceOf(address(actor)), 0);
        assertEq(gogeToken_v2.balanceOf(address(actor)), bal);
    }

    /// @notice Perform a buy
    function buy_generateFees(uint256 tradeAmt) public {

        IERC20(WBNB).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path = new address[](2);

        path[0] = WBNB;
        path[1] = address(gogeToken_v2);

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path,
            msg.sender,
            block.timestamp + 300
        );
    }

    /// @notice Perform a buy
    function sell_generateFees(uint256 tradeAmt) public {

        IERC20(address(gogeToken_v2)).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path = new address[](2);

        path[0] = address(gogeToken_v2);
        path[1] = WBNB;

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path,
            msg.sender,
            block.timestamp + 300
        );
    }

    // ~~ Unit Tests ~~

    /// @notice Initial state test.
    function test_mainDeployment_init_state() public {
        assertEq(gogeToken_v2.tradingIsEnabled(), true);
        assertEq(gogeToken_v2.migrationCounter(), 5);
    }

    /// @notice Tests buy post trading being enabled.
    function test_mainDeployment_buy() public {
        gogeToken_v2.excludeFromFees(address(this), false);

        // Verify address(this) is NOT excluded from fees and grab pre balance.
        assert(!gogeToken_v2.isExcludedFromFees(address(this)));
        uint256 preBal = gogeToken_v2.balanceOf(address(this));

        // Deposit 10 BNB
        uint BNB_DEPOSIT = 10 ether;
        IWETH(WBNB).deposit{value: BNB_DEPOSIT}();

        // approve purchase
        IERC20(WBNB).approve(address(UNIV2_ROUTER), 5 ether);

        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(gogeToken_v2);

        // Get Quoted amount
        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut( 5 ether, path );

        // Execute purchase
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            5 ether,
            0,
            path,
            address(this),
            block.timestamp + 300
        );

        // Grab post balanace and calc amount goge tokens received.
        uint256 postBal        = gogeToken_v2.balanceOf(address(this));
        uint256 amountReceived = (postBal - preBal);
        uint256 taxedAmount    = amounts[1] * gogeToken_v2.totalFees() / 100; //amounts[1] * 16%

        // Verify the quoted amount is the amount received and no royalties were generated.
        assertEq(amounts[1] - taxedAmount, amountReceived);
        assertEq(gogeToken_v2.balanceOf(address(gogeToken_v2)), taxedAmount);

        // Log
        emit log_uint(amounts[1]);
        emit log_uint(amountReceived);
        emit log_uint(gogeToken_v2.balanceOf(address(gogeToken_v2)));
    }

    /// @notice Tests sell post trading being enabled.
    function test_mainDeployment_sell() public {
        gogeToken_v2.excludeFromFees(address(this), false);

        // Verify address(this) is NOT excluded from fees and grab pre balance.
        assert(!gogeToken_v2.isExcludedFromFees(address(this)));
        uint256 preBal = IERC20(WBNB).balanceOf(address(this));

        uint256 tradeAmt = 1_000_000 ether;

        // approve sell
        IERC20(address(gogeToken_v2)).approve(address(UNIV2_ROUTER), tradeAmt);

        address[] memory path = new address[](2);
        path[0] = address(gogeToken_v2);
        path[1] = WBNB;

        // Get Quoted amount
        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut( tradeAmt, path );

        // Execute purchase
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path,
            address(this),
            block.timestamp + 300
        );

        // Grab post balanace and calc amount goge tokens received.
        uint256 postBal        = IERC20(WBNB).balanceOf(address(this));
        uint256 amountReceived = (postBal - preBal);
        uint256 afterTaxAmount = amounts[1] * 84 / 100;

        // Verify the quoted amount is the amount received and no royalties were generated.
        withinDiff(afterTaxAmount, amountReceived, 10**12);
        assertEq(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2)), amounts[0] * 16 / 100);

        // Log
        emit log_named_uint("amount bnb quoted", amounts[1]);
        emit log_named_uint("amount bnb received", amountReceived);
        emit log_named_uint("amount royalties", IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2)));
    }

    /// @notice Tests migrations post trading being enabled.
    function test_mainDeployment_migrationPostTradingEnabled() public {
        // Creating a new actor to migrate
        Actor jeff = new Actor();
        uint256 amountJeff = 1_000_000_000 ether;

        // Transfer v1 tokens to jeff
        gogeToken_v1.transfer(address(jeff), amountJeff);

        // Verify balance
        assertEq(gogeToken_v1.balanceOf(address(jeff)), amountJeff);

        // migrate
        migrateActor(jeff);
    }

    /// @notice verifies royalties are being distributed to all royalty wallets.
    function test_mainDeployment_feeDistributions_dev() public {

        // NOTE: Pre-state check. -------------------------------------------

        // Get pre balances of royalty recipients
        uint256 preBalMarketing = gogeToken_v2.marketingWallet().balance;
        uint256 preBalTeam      = gogeToken_v2.teamWallet().balance;
        uint256 preBalDev       = gogeToken_v2.devWallet().balance;

        // Remove address(this) from whitelist so we can yield a buy tax.
        gogeToken_v2.excludeFromFees(address(this), false);

        // Check balance of address(gogeToken_v2) to see how many tokens have been taxed. Should be 0
        assertEq(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2)), 0);


        // NOTE: Generate fees. -------------------------------------------

        // Generate buy -> log amount of tokens accrued
        buy_generateFees(10 ether);
        emit log_uint(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2))); // 72561945.896794726074107751
        emit log_uint(address(gogeToken_v2).balance); // 0

        // Get amount of tokens for royalties
        uint256 amountTokensForRoyalties = IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2));

        // Quote tokens for wbnb
        address[] memory path = new address[](2);
        path[0] = address(gogeToken_v2);
        path[1] = WBNB;

        // Get Quoted amount
        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut( amountTokensForRoyalties , path );

        // log bnb
        emit log_named_uint("bnb for royalties", amounts[1]); // 1.719750966813013582

        // Generate sell -> Distribute fees
        sell_generateFees(1_000 ether);
        emit log_uint(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2))); // 1600.00000000000000000
        emit log_uint(address(gogeToken_v2).balance); // 0


        // NOTE: Post-state check. -------------------------------------------

        // take post balanaces
        uint256 postBalMarketing = gogeToken_v2.marketingWallet().balance;
        uint256 postBalTeam      = gogeToken_v2.teamWallet().balance;
        uint256 postBalDev       = gogeToken_v2.devWallet().balance;

        // verify that the royalty recipients have indeed recieved royalties
        assertGt(postBalMarketing, preBalMarketing);
        assertGt(postBalTeam,      preBalTeam);
        assertGt(postBalDev,       preBalDev);

        // very amount received
        uint256 marketingReceived = postBalMarketing - preBalMarketing;
        uint256 teamReceived      = postBalTeam - preBalTeam;
        uint256 devReceived       = postBalDev - preBalDev;

        // Verify amount received is amount sent
        assertEq(marketingReceived, gogeToken_v2.royaltiesSent(1));
        assertEq(teamReceived,      gogeToken_v2.royaltiesSent(3));
        assertEq(devReceived,       gogeToken_v2.royaltiesSent(2));

        // Verify all royalties sent equate to the amount of bnb sold for royalties
        assertEq(amounts[1],        gogeToken_v2.royaltiesSent(1) + 
                                    gogeToken_v2.royaltiesSent(2) + 
                                    gogeToken_v2.royaltiesSent(3) + 
                                    gogeToken_v2.royaltiesSent(4) + 
                                    gogeToken_v2.royaltiesSent(5));

        // Verify royalty amounts
        withinDiff(gogeToken_v2.royaltiesSent(1), amounts[1] * gogeToken_v2.marketingFee() / gogeToken_v2.totalFees(), 1); // markeing
        withinDiff(gogeToken_v2.royaltiesSent(2), amounts[1] * 2 / gogeToken_v2.totalFees(), 1);                           // dev
        withinDiff(gogeToken_v2.royaltiesSent(3), amounts[1] * gogeToken_v2.teamFee() / gogeToken_v2.totalFees(), 1);      // team
        withinDiff(gogeToken_v2.royaltiesSent(4), amounts[1] * gogeToken_v2.buyBackFee() / gogeToken_v2.totalFees(), 1);   // buyback
        withinDiff(gogeToken_v2.royaltiesSent(5), amounts[1] * 8 / gogeToken_v2.totalFees(), 1);                           // cake

        // log amount
        emit log_named_uint("marketing", gogeToken_v2.royaltiesSent(1));
        emit log_named_uint("dev",       gogeToken_v2.royaltiesSent(2));
        emit log_named_uint("team",      gogeToken_v2.royaltiesSent(3));
        emit log_named_uint("buyback",   gogeToken_v2.royaltiesSent(4));
        emit log_named_uint("cake",      gogeToken_v2.royaltiesSent(5));
    }

    /// @notice verifies royalties are being distributed to all royalty wallets after the 60 day dev tax.
    function test_mainDeployment_feeDistributions_noDev() public {

        // NOTE: Pre-state check. -------------------------------------------

        // Get pre balances of royalty recipients
        uint256 preBalMarketing = gogeToken_v2.marketingWallet().balance;
        uint256 preBalTeam      = gogeToken_v2.teamWallet().balance;
        uint256 preBalDev       = gogeToken_v2.devWallet().balance;

        // Remove address(this) from whitelist so we can yield a buy tax.
        gogeToken_v2.excludeFromFees(address(this), false);

        // warp in time 60 days -> outside dev tax timeframe.
        vm.warp(block.timestamp + 60 days);

        // Check balance of address(gogeToken_v2) to see how many tokens have been taxed. Should be 0
        assertEq(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2)), 0);


        // NOTE: Generate fees. -------------------------------------------

        // Generate buy -> log amount of tokens accrued
        buy_generateFees(10 ether);
        emit log_uint(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2))); // 72561945.896794726074107751
        emit log_uint(address(gogeToken_v2).balance); // 0

        // Get amount of tokens for royalties
        uint256 amountTokensForRoyalties = IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2));

        // Quote tokens for wbnb
        address[] memory path = new address[](2);
        path[0] = address(gogeToken_v2);
        path[1] = WBNB;

        // Get Quoted amount
        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut( amountTokensForRoyalties , path );

        // log bnb
        emit log_named_uint("bnb for royalties", amounts[1]); // 1.719750966813013582

        // Generate sell -> Distribute fees
        sell_generateFees(1_000 ether);
        emit log_uint(IERC20(address(gogeToken_v2)).balanceOf(address(gogeToken_v2))); // 1600.00000000000000000
        emit log_uint(address(gogeToken_v2).balance); // 0


        // NOTE: Post-state check. -------------------------------------------

        // take post balanaces
        uint256 postBalMarketing = gogeToken_v2.marketingWallet().balance;
        uint256 postBalTeam      = gogeToken_v2.teamWallet().balance;
        uint256 postBalDev       = gogeToken_v2.devWallet().balance;

        // verify that the royalty recipients have indeed recieved royalties
        assertGt(postBalMarketing, preBalMarketing);
        assertGt(postBalTeam,      preBalTeam);
        assertEq(postBalDev,       preBalDev);

        // very amount received
        uint256 marketingReceived = postBalMarketing - preBalMarketing;
        uint256 teamReceived      = postBalTeam - preBalTeam;
        uint256 devReceived       = postBalDev - preBalDev;

        // Verify amount received is amount sent.
        assertEq(marketingReceived, gogeToken_v2.royaltiesSent(1));
        assertEq(teamReceived,      gogeToken_v2.royaltiesSent(3));
        assertEq(devReceived,       gogeToken_v2.royaltiesSent(2));
        assertEq(devReceived,       0);

        // Verify all royalties sent equate to the amount of bnb sold for royalties -> not including dev tax
        assertEq(amounts[1],        gogeToken_v2.royaltiesSent(1) +  
                                    gogeToken_v2.royaltiesSent(3) + 
                                    gogeToken_v2.royaltiesSent(4) + 
                                    gogeToken_v2.royaltiesSent(5));

        // Verify royalty amounts
        withinDiff(gogeToken_v2.royaltiesSent(1), amounts[1] * gogeToken_v2.marketingFee() / gogeToken_v2.totalFees(), 1); // markeing
        withinDiff(gogeToken_v2.royaltiesSent(3), amounts[1] * gogeToken_v2.teamFee() / gogeToken_v2.totalFees(), 1);      // team
        withinDiff(gogeToken_v2.royaltiesSent(4), amounts[1] * gogeToken_v2.buyBackFee() / gogeToken_v2.totalFees(), 1);   // buyback
        withinDiff(gogeToken_v2.royaltiesSent(5), amounts[1] * 10 / gogeToken_v2.totalFees(), 2);                          // cake

        // log amount
        emit log_named_uint("marketing", gogeToken_v2.royaltiesSent(1));
        emit log_named_uint("dev",       gogeToken_v2.royaltiesSent(2));
        emit log_named_uint("team",      gogeToken_v2.royaltiesSent(3));
        emit log_named_uint("buyback",   gogeToken_v2.royaltiesSent(4));
        emit log_named_uint("cake",      gogeToken_v2.royaltiesSent(5));
    }

}
