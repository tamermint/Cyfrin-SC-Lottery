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
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256, uint256, uint256);

    //Type declaration
    enum RaffleState {
        OPEN,
        CALCULATING
    }

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
    address payable s_recentWinner;
    RaffleState private s_raffleState;

    //events
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed recentWinner);
    event WinnerRequested(uint256 indexed requestId);
    event UnsolicitedTransfer(address indexed sender, uint256 indexed amount);

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
        s_raffleState = RaffleState.OPEN;
    }

    /**
     * @notice Enter the raffle by paying the required entrance fee.
     * @dev Reverts if raffle is not open or msg.value is less than the entrance fee.
     */
    function enterRaffle() external payable {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        //Players need to pay an entrance fee to okay in the raffle
        //one way to revert, only works in 0.8.26 and above pragmas
        //require(msg.value >= i_entranceFee, SendMoreToEnterRaffle());
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @notice Check whether upkeep (winner selection) should be performed.
     * @dev This is a view helper intended to be used by Chainlink Keepers / off-chain checks.
     * Uses internal state and timing to decide if upkeep is needed.
     * @return upkeepNeeded True if upkeep should be performed, false otherwise.
     * @return Empty bytes for performData.
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    )
        public
        view
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length != 0;
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;

        upkeepNeeded = isOpen && hasBalance && hasPlayers && timeHasPassed;
        return (upkeepNeeded, "");
    }

    /**
     * @notice Perform upkeep by requesting random words from the VRF coordinator.
     * @dev Sets raffle state to CALCULATING and requests randomness. Reverts if upkeep conditions are not met.
     * @param - Unused parameter (for Chainlink Keeper compatibility).
     */
    function performUpkeep(
        bytes memory /* performData */
    )
        external
    {
        (bool upKeepNeeded,) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestID = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gaslane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false})) // new parameter
            })
        );
        emit WinnerRequested(requestID);
    }

    /**
     * @notice Callback used by VRF coordinator to provide random words.
     * @dev Picks the winner, resets raffle state, transfers the balance, and emits WinnerPicked event.
     * Reverts if not enough time has passed since last draw or if transfer fails.
     * @param randomWords Array of random words provided by the VRF coordinator; only the first word is used.
     */
    function fulfillRandomWords(
        uint256,
        /*requestId*/
        uint256[] memory randomWords
    )
        internal
        override
    {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert Raffle__NotEnoughTimeHasPassed();
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(s_recentWinner);
    }

    /**
     * @notice Get the entrance fee required to join the raffle.
     * @return The entrance fee in wei.
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    /**
     * @notice Get the player address at a specific index.
     * @param index The index of the player to query.
     * @return The address of the player at the specified index.
     */
    function getPlayers(uint256 index) public view returns (address) {
        return s_players[index];
    }

    /**
     * @notice Get the number of confirmations required for VRF requests.
     * @return The configured request confirmation count.
     */
    function getRequestConfirmations() public pure returns (uint16) {
        return REQUEST_CONFIRMATIONS;
    }

    /**
     * @notice Get the number of random words requested from VRF.
     * @return The number of words.
     */
    function getNumWords() public pure returns (uint32) {
        return NUM_WORDS;
    }

    /**
     * @notice Get the total number of players currently in the raffle.
     * @return The player count.
     */
    function getNumPlayers() public view returns (uint256) {
        return s_players.length;
    }

    /**
     * @notice Get the current state of the raffle.
     * @return The current raffle state (OPEN or CALCULATING).
     */
    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    /**
     * @notice handle simple ether transfers
     */
    receive() external payable {
        emit UnsolicitedTransfer(msg.sender, msg.value);
    }
}

