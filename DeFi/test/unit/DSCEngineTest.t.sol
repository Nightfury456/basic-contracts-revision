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
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
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
        vm.startPrank(USER);
        ERC20Mock bnb = new ERC20Mock("BNB", "BNB", msg.sender, STARTING_ERC20_BALANCE);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dsce.depositCollateral(address(bnb), 1e18);
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
}
