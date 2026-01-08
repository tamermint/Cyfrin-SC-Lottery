// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "../../src/raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    //EVENTS
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed recentWinner);
    event WinnerRequested(uint256 indexed requestId);
    event UnsolicitedTransfer(address indexed sender, uint256 indexed amount);

    Raffle public raffle;
    MockLinkToken token;
    HelperConfig public helperConfig;

    bytes32 gaslane;
    uint256 entranceFee;
    uint256 interval;
    uint256 subscriptionId;
    uint16 minimumRequestConfirmations;
    uint32 callbackGasLimit;
    uint32 numWords;
    address vrfCoordinator;

    address public PLAYER = makeAddr("player");
    address public PLAYER2 = makeAddr("player2");
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        vm.deal(PLAYER, STARTING_BALANCE);
        vm.deal(PLAYER2, STARTING_BALANCE);
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfCoordinator = networkConfig.vrfCoordinator;
        gaslane = networkConfig.gasLane;
        subscriptionId = networkConfig.subscriptionId;
        callbackGasLimit = networkConfig.callbackGasLimit;

        raffle = new Raffle(entranceFee, interval, vrfCoordinator, gaslane, subscriptionId, callbackGasLimit);

        vm.startPrank(msg.sender);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, 100 ether);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, address(raffle));
        vm.stopPrank();
    }

    modifier RaffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    //RAFFLE TESTS

    function testRaffleStateIsOpenWhenContractIsInitialized() public view {
        uint256 state = uint256(uint8(raffle.getRaffleState()));
        console.logUint(state);
        assertEq(state, uint256(uint8(Raffle.RaffleState.OPEN)));
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

    function testDontAllowPlayersToEnterWhenRaffleIsCalculating() public RaffleEntered {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER2);
        raffle.enterRaffle{value: entranceFee}();
    }

    //CHECKUPKEEP TESTS

    function testCheckUpKeepFailsIfNoBalance() public {
        //this also tests if s_players.length == 0
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public RaffleEntered {
        //Arrange
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseIfNoPlayers() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        (bool s,) = address(raffle).call{value: 2 ether}("");
        require(s);

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpKeepReturnsTrueIfAllConditionsArePassed() public RaffleEntered {
        //Act
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        //assert
        assert(upKeepNeeded);
    }

    function testUnsolicitedTransferEmitsEvent() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);

        vm.expectEmit(true, true, false, false, address(raffle));
        emit UnsolicitedTransfer(PLAYER, 2 ether);

        (bool s,) = address(raffle).call{value: 2 ether}("");
        require(s);
    }

    //Perform Upkeep tests
    function testPerformUpKeepRunsOnlyIfCheckUpKeepNeededIsTrue() public RaffleEntered {
        //Act/Assert
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        uint256 numPlayers = 0;
        uint256 balance = address(raffle).balance;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        numPlayers = 1;
        balance = balance + entranceFee;

        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, balance, numPlayers, rState));
        raffle.performUpkeep("");
    }

    function testPerformUpKeepUpdatesRaffleState() public RaffleEntered {
        //Act
        raffle.performUpkeep("");
        Raffle.RaffleState rState = raffle.getRaffleState();

        //Assert
        assert(rState == Raffle.RaffleState.CALCULATING);
    }

    function testPerformUpKeepEmitsEvent() public RaffleEntered {
        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        //Assert
        assert(uint256(requestId) > 0);
    }

    //Getter Tests
    function testEntranceFee() public view {
        uint256 entranceFeeTest = raffle.getEntranceFee();
        assertEq(entranceFeeTest, entranceFee);
    }

    function testGetPlayersAddress() public RaffleEntered {
        assertEq(address(PLAYER), raffle.getPlayers(0));
    }

    function testGetRequestConfirmations() public view {
        assertEq(raffle.getRequestConfirmations(), 3);
    }

    function testGetNumWords() public view {
        assertEq(raffle.getNumWords(), 1);
    }

    function testGetNumPlayers() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getNumPlayers(), 1);
    }
}
