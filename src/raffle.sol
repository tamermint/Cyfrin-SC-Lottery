// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title Raffle Contract - followed with Cyfrin Updraft
 * @author Vivek Mitra
 * @notice This contract is a simple contract for a raffle system. Players enter the contract by paying a fixed amount of ETH. At a set interval, a random winner is selected who receives the entire balance of the contract.
 * @dev Implements Chainlink VRF v2.5 for randomness and Chainlink Keepers for automated execution.
 */
contract Raffle {}
