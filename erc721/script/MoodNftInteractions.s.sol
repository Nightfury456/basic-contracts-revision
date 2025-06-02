// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {MoodNft} from "../src/MoodNft.sol";

contract MoodNftInteractions is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("MoodNft", block.chainid);
        mintNftOnContract(mostRecentlyDeployed);
        uint256 tokenId = MoodNft(mostRecentlyDeployed).getTokenCounter() - 1;
        flipMoodOnContract(mostRecentlyDeployed, tokenId);
    }

    function mintNftOnContract(address contractAddress) public {
        vm.startBroadcast();
        MoodNft(contractAddress).mintNft();
        vm.stopBroadcast();
    }

    function flipMoodOnContract(address contractAddress, uint256 tokenId) public {
        vm.startBroadcast();
        MoodNft(contractAddress).flipMood(tokenId);
        vm.stopBroadcast();
    }
}
