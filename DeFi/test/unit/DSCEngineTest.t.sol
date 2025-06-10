// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {Test, console} from "forge-std/Test.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant AMOUNT_TO_MINT = 5000e18; // 1000 DSC

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        uint256 amountToDeposit = STARTING_ERC20_BALANCE;
        ERC20Mock(weth).approve(address(dsce), amountToDeposit);
        dsce.depositCollateral(weth, amountToDeposit);
        _;
        vm.stopPrank();
    }

    modifier mintDsc() {
        vm.startPrank(USER);
        uint256 dscAmountToMint = AMOUNT_TO_MINT;
        dsce.mintDsc(dscAmountToMint);
        _;
        vm.stopPrank();
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertIfTokenLengthAndPriceFeesLengthMismatch() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed); // Intentionally mismatched length

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedLengthMismatch.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////
    // Price Tests //
    /////////////////
    function testGetUsdValue() public {
        uint256 ethAmount = 10e18;
        // 10e18 * 2000/ETH = 20000e18
        uint256 expectedUsd = 20000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testgetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        // 100e18 / 2000e18 = 10e18
        uint256 expectedEthAmount = 0.05 ether;
        uint256 actualEthAmount = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedEthAmount, actualEthAmount);
    }

    /////////////////////////////
    // depositCollateral Tests //
    /////////////////////////////

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testTokenNotAllowed() public {
        ERC20Mock bnb = new ERC20Mock("BNB", "BNB", USER, STARTING_ERC20_BALANCE);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dsce.depositCollateral(address(bnb), STARTING_ERC20_BALANCE);
        vm.stopPrank();
    }

    function testDepositCollateral() public {
        vm.startPrank(USER);
        uint256 amountToDeposit = STARTING_ERC20_BALANCE;
        ERC20Mock(weth).approve(address(dsce), amountToDeposit);
        dsce.depositCollateral(weth, amountToDeposit);

        uint256 userCollateralBalance = dsce.getUserCollateralBalance(USER, weth);
        assertEq(userCollateralBalance, amountToDeposit);

        uint256 contractBalance = ERC20Mock(weth).balanceOf(address(dsce));
        assertEq(contractBalance, amountToDeposit);
        vm.stopPrank();
    }

    function testMintDsc() public {
        vm.startPrank(USER);
        uint256 amountToDeposit = STARTING_ERC20_BALANCE;
        ERC20Mock(weth).approve(address(dsce), amountToDeposit);
        dsce.depositCollateral(weth, amountToDeposit);

        uint256 dscAmountToMint = 1000e18;
        dsce.mintDsc(dscAmountToMint);

        uint256 userDscBalance = dsc.balanceOf(USER);
        assertEq(userDscBalance, dscAmountToMint);

        uint256 contractDscBalance = dsc.balanceOf(address(dsce));
        assertEq(contractDscBalance, 0);
        vm.stopPrank();
    }

    function testDepositCollateralAndMintDsc() public {
        vm.startPrank(USER);

        uint256 amountToDeposit = STARTING_ERC20_BALANCE;
        uint256 dscAmountToMint = 1000e18;

        ERC20Mock(weth).approve(address(dsce), amountToDeposit);

        dsce.depositCollateralAndMintDsc(weth, amountToDeposit, dscAmountToMint);

        uint256 userCollateralBalance = dsce.getUserCollateralBalance(USER, weth);
        assertEq(userCollateralBalance, amountToDeposit);

        uint256 userDscBalance = dsc.balanceOf(USER);
        assertEq(userDscBalance, dscAmountToMint);

        uint256 contractDscBalance = dsc.balanceOf(address(dsce));
        assertEq(contractDscBalance, 0);

        vm.stopPrank();
    }

    ////////////////////////////
    // redeemCollateral Tests //
    ////////////////////////////

    function testRedeemCollateralForDsc_Success() public {
        vm.startPrank(USER);

        uint256 depositAmount = 10 ether;
        ERC20Mock(weth).mint(USER, depositAmount); // give user collateral
        ERC20Mock(weth).approve(address(dsce), depositAmount);
        dsce.depositCollateral(address(weth), depositAmount);

        // Mint DSC safely (e.g., 50% LTV of $10 worth WETH = $5)
        uint256 mintAmount = 5e18; // $5 worth
        dsce.mintDsc(mintAmount);

        // Approve DSC burn
        ERC20Mock(address(dsc)).approve(address(dsce), mintAmount);

        // Call redeemCollateralForDsc
        dsce.redeemCollateralForDsc(address(weth), 2 ether, mintAmount);

        // Assertions
        uint256 remainingCollateral = dsce.getUserCollateralBalance(USER, address(weth));
        uint256 remainingDsc = dsc.balanceOf(USER);

        assertEq(remainingCollateral, 8 ether); // 10 deposited - 2 redeemed
        assertEq(remainingDsc, 0); // all burned
        assertTrue(dsce.getHealthFactor(USER) >= 1e18);
    }

    function testRedeemCollateral() public depositCollateral {
        vm.startPrank(USER);
        uint256 startingBalance = ERC20Mock(weth).balanceOf(USER);
        uint256 amountToRedeem = 1 ether;

        dsc.approve(address(dsce), amountToRedeem);
        dsce.redeemCollateral(weth, amountToRedeem);
        uint256 userCollateralBalance = dsce.getUserCollateralBalance(USER, weth);

        uint256 afterBalance = ERC20Mock(weth).balanceOf(USER);

        assertEq(userCollateralBalance, 9 ether);
        assertEq(afterBalance, startingBalance + amountToRedeem);
        vm.stopPrank();
    }

    // function testExpectRevertIfHealthFactorBrokenWhileRedeeming() public depositCollateral {
    //     vm.startPrank(USER);
    //     uint256 mintAmount = 5000e18; // in usd
    //     dsce.mintDsc(mintAmount);

    //     uint256 amountToRedeem = 8 ether;
    //     vm.expectRevert(DSCEngine.DSCEngine__HealthFactorIsBroken.selector);

    //     dsc.approve(address(dsce), amountToRedeem);
    //     dsce.redeemCollateral(weth, amountToRedeem);

    //     vm.stopPrank();
    // }

    function testBurnDsc() public depositCollateral mintDsc {
        vm.startPrank(USER);

        uint256 userDscBalanceBeforeBurn = dsc.balanceOf(USER);
        assertEq(userDscBalanceBeforeBurn, AMOUNT_TO_MINT);

        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        dsce.burnDsc(AMOUNT_TO_MINT);

        uint256 userDscBalanceAfterBurn = dsc.balanceOf(USER);
        assertEq(userDscBalanceAfterBurn, 0);

        vm.stopPrank();
    }

    ///////////////////////
    // Liquidation Tests //
    ///////////////////////

    // function testLiquidate_Succeeds() public depositCollateral mintDsc {
    //     // Drop price to make health factor < 1
    //     // Assume 1 WETH = $1000 initially, now drop to $400
    //     mockPriceFeed(address(weth), 400e8); // if using ChainlinkAggregatorMock

    //     // Liquidator gets DSC
    //     vm.startPrank(LIQUIDATOR);
    //     dsc.mint(LIQUIDATOR, amountToMint);
    //     dsc.approve(address(dsce), amountToMint);

    //     // Liquidate
    //     dsce.liquidate(address(weth), USER, amountToMint);
    //     vm.stopPrank();

    //     // Check that:
    //     // - LIQUIDATOR received some collateral
    //     // - USER has less or no collateral
    //     // - DSC debt is reduced
    //     uint256 liquidatorCollateral = dsce.getCollateralBalanceOfUser(LIQUIDATOR, address(weth));
    //     assertGt(liquidatorCollateral, 0);
    //     assertEq(dsce.getDscMinted(USER), 0);
    // }

    // function testLiquidate_RevertsIfHealthFactorOk() public {
    //     uint256 depositAmount = 10 ether;
    //     uint256 mintAmount = 5e18;

    //     // USER sets up
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).mint(USER, depositAmount);
    //     weth.approve(address(dsce), depositAmount);
    //     dsce.depositCollateral(address(weth), depositAmount);
    //     dsce.mintDsc(mintAmount);
    //     vm.stopPrank();

    //     // Price is still safe
    //     vm.startPrank(LIQUIDATOR);
    //     dsc.mint(LIQUIDATOR, mintAmount);
    //     dsc.approve(address(dsce), mintAmount);

    //     vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
    //     dsce.liquidate(address(weth), USER, mintAmount);
    //     vm.stopPrank();
    // }

    // function testLiquidate_RevertsIfHealthFactorNotImproved() public {
    //     uint256 depositAmount = 10 ether;
    //     uint256 mintAmount = 5e18;

    //     // Setup
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).mint(USER, depositAmount);
    //     weth.approve(address(dsce), depositAmount);
    //     dsce.depositCollateral(address(weth), depositAmount);
    //     dsce.mintDsc(mintAmount);
    //     vm.stopPrank();

    //     // Price drops
    //     mockPriceFeed(address(weth), 300e8);

    //     // Liquidator tries to cover too little debt
    //     vm.startPrank(LIQUIDATOR);
    //     dsc.mint(LIQUIDATOR, 1e18);
    //     dsc.approve(address(dsce), 1e18);

    //     vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
    //     dsce.liquidate(address(weth), USER, 1e18);
    //     vm.stopPrank();
    // }

    function testGetAccountCollateralValue() public depositCollateral {
        vm.startPrank(USER);
        uint256 collateralValue = dsce.getAccountCollateralValue(USER);
        // 10 ether * 2000 USD/ETH = 20000 USD
        assertEq(collateralValue, 20000e18);
        vm.stopPrank();
    }
}
