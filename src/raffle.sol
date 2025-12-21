// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title Raffle Contract - followed with Cyfrin Updraft
 * @author Vivek Mitra
 * @notice This contract is a simple contract for a raffle system. Players enter the contract by paying a fixed amount of ETH. At a set interval, a random winner is selected who receives the entire balance of the contract.
 * @dev Implements Chainlink VRF v2.5 for randomness and Chainlink Keepers for automated execution.
 */
contract Raffle {
    //errors
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__NotEnoughTimeHasPassed();

    //State variables
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; //@dev time since the last lottery occurred
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;

    //events
    event EnteredRaffle(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
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
    }

    /* GETTERS */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers() public view returns (address payable[] memory) {
        return s_players;
    }
}

