// SPDX-Licnese-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {OurToken} from "../src/OurToken.sol";

contract OurTokenTest is Test {
    OurToken public ourToken;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    uint256 constant INITIAL_SUPPLY = 1000 ether;
    uint256 constant STARTING_BALANCE = 100 ether;

    function setUp() public {
        ourToken = new OurToken(INITIAL_SUPPLY);

        vm.prank(address(this));
        ourToken.transfer(bob, STARTING_BALANCE);
    }

    function testBobBalance() public view {
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
    }

    function testAllowances() public {
        vm.prank(bob);
        ourToken.approve(alice, STARTING_BALANCE);
        assertEq(ourToken.allowance(bob, alice), STARTING_BALANCE);

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, STARTING_BALANCE);
        assertEq(ourToken.balanceOf(alice), STARTING_BALANCE);
        assertEq(ourToken.balanceOf(bob), 0);
    }
}
