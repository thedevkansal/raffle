// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// type declarations
// state variables
// events
// modifiers
// functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console2} from "forge-std/console2.sol";

/**
 * @title Raffle
 * @author Dev Kansal
 * @notice This contract allows users to enter a raffle by sending Ether.
 * @dev Implements a simple raffle system using Chainlink VRF v2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    // Errors
    error Raffle__SendMoreETHtoEnterRaffle();
    error Raffle__TransferToWinnerFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

    // Enum
    enum RaffleState {
        OPEN, //0
        CALCULATING //1

    }

    // State Variables
    // Chainlink VRF v2.5 parameters
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint32 private immutable i_callbackGasLimit;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;

    // Raffle parameters
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // Events
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    // Constructor
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gaslane,
        uint256 subscriptionID,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        require(vrfCoordinator != address(0), "Invalid VRF coordinator");
        s_lastTimeStamp = block.timestamp;
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gaslane;
        i_subscriptionId = subscriptionID;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    //Functions

    // This function allows users to enter the raffle by sending Ether
    function enterRaffle() public payable {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreETHtoEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // This function is called by Chainlink VRF to check if upkeep is needed
    function checkUpkeep(bytes memory /*checkData*/ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /*performData*/ )
    {
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasETH = address(this).balance > 0;
        return (upkeepNeeded = (isOpen && timePassed && hasPlayers && hasETH), bytes(""));
    }

    // This function is called by Chainlink VRF to perform upkeep
    function performUpkeep(bytes calldata /*performData*/ ) external {
        // Check if upkeep is needed
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        // Update the raffle state to CALCULATING
        s_raffleState = RaffleState.CALCULATING;

        // Request random words from Chainlink VRF
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            callbackGasLimit: i_callbackGasLimit,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}))
        });

        // The requestID is used to track the request and fulfill it later
        uint256 requestID = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestID);
    }

    // Callback function to fulfill the random words request
    function fulfillRandomWords(uint256, /*requestId*/ uint256[] calldata randomWords) internal override {
        //Pick a random winner from the players
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        // Reset the raffle state, players array, and last timestamp
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        emit WinnerPicked(recentWinner);

        console2.log("Balance before sending:", address(this).balance);

        // Transfer the balance to the winner
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferToWinnerFailed();
        }
        console2.log("Balance after sending:", address(this).balance);
    }

    // Fallback function to allow users to enter the raffle by sending Ether directly
    receive() external payable {
        enterRaffle();
    }

    // View Functions
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 playerIndex) external view returns (address) {
        return s_players[playerIndex];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getPlayersCount() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }
}
