// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function run() external {
        createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helper = new HelperConfig();
        address vrfCoordinator = helper.getConfig().vrfCoordinator;
        address account = helper.getConfig().account;
        (uint256 subId,) = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
        console.log("Creating subscription on chain id: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscriptionId is: ", subId);
        console.log("Please update subId in Helper config");

        return (subId, vrfCoordinator);
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether;

    function run() external {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helper = new HelperConfig();
        address vrfCoordinator = helper.getConfig().vrfCoordinator;
        uint256 subscriptionId = helper.getConfig().subscriptionId;
        address account = helper.getConfig().account;
        address linkToken = helper.getConfig().link;

        if (subscriptionId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (uint256 subId, address vrfV2) = createSub.createSubscriptionUsingConfig();
            subscriptionId = subId;
            vrfCoordinator = vrfV2;
            console.log("New subscription created: ", subscriptionId);
            console.log("New VRF Coordinator address: ", vrfCoordinator);
        }

        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account)
        public
    {
        console.log("Funding Subscription: ", subscriptionId);
        console.log("VRF Coordinator: ", vrfCoordinator);
        console.log("On chain id: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function run() external {
        address mostRecentlyDeployedConsumer = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployedConsumer);
    }

    function addConsumerUsingConfig(address mostRecentlyDeployedConsumer) public {
        HelperConfig helper = new HelperConfig();
        uint256 subscriptionId = helper.getConfig().subscriptionId;
        address vrfCoordinator = helper.getConfig().vrfCoordinator;
        address account = helper.getConfig().account;
        addConsumer(mostRecentlyDeployedConsumer, vrfCoordinator, subscriptionId, account);
    }

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subscriptionId, address account)
        public
    {
        console.log("Adding Consumer Contract: ", contractToAddToVrf);
        console.log("VRF Coordinator: ", vrfCoordinator);
        console.log("On chain: ", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, contractToAddToVrf);
        vm.stopBroadcast();
    }
}
