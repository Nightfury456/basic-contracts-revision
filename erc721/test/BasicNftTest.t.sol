// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";

import {DeployBasicNft} from "../script/DeployBasicNft.s.sol";
import {BasicNft} from "../src/BasicNft.sol";

contract BasicNftTest is Test {
    DeployBasicNft public deployer;
    BasicNft public basicNft;
    address user = makeAddr("user");
    string public constant PUG_URI =
        "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";

    function setUp() public {
        deployer = new DeployBasicNft();
        basicNft = deployer.run();
    }

    function testName() public view {
        string memory expectedName = "BasicNFT";
        string memory actualName = basicNft.name();
        assertEq(actualName, expectedName);
        // assert(keccak256(abi.encodePacked(actualName)) == keccak256(abi.encodePacked(expectedName)));
    }

    function testCanMintAndHaveABalance() public {
        console.log(basicNft.getTokenCounter()); //0
        vm.prank(user);
        basicNft.mintNft(PUG_URI);
        uint256 balance = basicNft.balanceOf(user);
        console.log(basicNft.getTokenCounter()); //1
        assertEq(balance, 1);
        assert(keccak256(abi.encodePacked(PUG_URI)) == keccak256(abi.encodePacked(basicNft.tokenURI(0))));
    }
}
