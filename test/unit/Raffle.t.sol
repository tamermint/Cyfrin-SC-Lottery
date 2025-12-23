// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Raffle} from "../../src/raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    //EVENTS
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    address v2_5Coordinator;
    MockLinkToken token;
    HelperConfig config;

    bytes32 gaslane;
    uint256 entranceFee;
    uint256 interval;
    uint256 subscriptionId;
    uint16 minimumRequestConfirmations;
    uint32 callbackGasLimit;
    uint32 numWords;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        config = new HelperConfig();
        vm.deal(PLAYER, STARTING_BALANCE);
        (entranceFee, interval, v2_5Coordinator, gaslane, subscriptionId, callbackGasLimit) =
            config.activeNetworkConfig();
        raffle = new Raffle(entranceFee, interval, v2_5Coordinator, gaslane, subscriptionId, callbackGasLimit);

        vm.startPrank(msg.sender);
        VRFCoordinatorV2_5Mock(v2_5Coordinator).fundSubscription(subscriptionId, 100 ether);
        vm.stopPrank();
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testAfterPayingEntranceFeePlayerIsAdded() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayers(0);

        vm.assertEq(playerRecorded, PLAYER);
    }

    function testEventIsEmittedAfterAddingPlayer() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }
}
