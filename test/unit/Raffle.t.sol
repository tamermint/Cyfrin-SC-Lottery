// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Raffle} from "../../src/raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    //EVENTS
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    MockLinkToken token;
    HelperConfig helper;

    bytes32 gaslane;
    uint256 entranceFee;
    uint256 interval;
    uint256 subscriptionId;
    uint16 minimumRequestConfirmations;
    uint32 callbackGasLimit;
    uint32 numWords;
    VRFCoordinatorV2_5Mock vrfCoordinator;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        helper = new HelperConfig();
        vm.deal(PLAYER, STARTING_BALANCE);
        HelperConfig.NetworkConfig memory networkConfig = helper.getConfig();
        raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vrfCoordinator = VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator);
        subscriptionId = networkConfig.subscriptionId;
        entranceFee = networkConfig.entranceFee;
        vm.startPrank(msg.sender);
        vrfCoordinator.fundSubscription(subscriptionId, 100 ether);
        vrfCoordinator.addConsumer(subscriptionId, address(raffle));
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

    function testRaffleStateIsOpenWhenContractIsInitialized() public view {
        uint256 state = uint256(uint8(raffle.getRaffleState()));
        console.logUint(state);
        assertEq(state, uint256(uint8(Raffle.RaffleState.OPEN)));
    }
}
