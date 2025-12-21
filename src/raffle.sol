// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle Contract - followed with Cyfrin Updraft
 * @author Vivek Mitra
 * @notice This contract is a simple contract for a raffle system. Players enter the contract by paying a fixed amount of ETH. At a set interval, a random winner is selected who receives the entire balance of the contract.
 * @dev Implements Chainlink VRF v2.5 for randomness and Chainlink Keepers for automated execution.
 */
contract Raffle is VRFConsumerBaseV2Plus {
    //errors
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__NotEnoughTimeHasPassed();

    //State variables
    //Chainlink variables
    bytes32 private immutable i_gaslane;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //Lottery variables
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; //@dev time since the last lottery occurred
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;

    //events
    event EnteredRaffle(address indexed player);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinatorV2,
        bytes32 gaslane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_gaslane = gaslane;
        i_interval = interval;
        i_entranceFee = entranceFee;
        i_subscriptionId = subscriptionId;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        //Players need to pay an entrance fee to okay in the raffle
        //one way to revert, only works in 0.8.26 and above pragmas
        //require(msg.value >= i_entranceFee, SendMoreToEnterRaffle());
        if (msg.value <= i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() external {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert Raffle__NotEnoughTimeHasPassed();
        }
        //get random numbers
        // request random number
        //get random number
    }

    function requestRandomWords() internal returns (uint256 requestID) {
        requestID = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gaslane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false})) // new parameter
            })
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {}

    /* GETTERS */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers() public view returns (address payable[] memory) {
        return s_players;
    }
}

