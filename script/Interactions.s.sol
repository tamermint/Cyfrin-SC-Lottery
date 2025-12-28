// SPDX-License-Identifier: MIT

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

pragma solidity 0.8.19;

contract CreateSubscription is Script {
    function run() external {
        createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helper = new HelperConfig();
        address vrfCoordinator = helper.getConfig().vrfCoordinator;
        (uint256 subId,) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256, address) {
        console.log("Creating subscription on chain id: ", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscriptionId is: ", subId);
        console.log("Please update subId in Helper config");

        return (subId, vrfCoordinator);
    }
}

contract FundSubscription is Script {
    uint256 public constant FUND_AMOUNT = 3 ether;

    function run() external {}

    function fundSubscriptionUsingConfig() public {
        CreateSubscription createSubscription = new CreateSubscription();
        (uint256 subId, address vrfCoordinator) = createSubscription.createSubscriptionUsingConfig();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
    }

    function fundSubscription(uint256 subscriptionId) public {}
}
