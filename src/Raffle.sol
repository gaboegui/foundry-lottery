// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle.sol is a Simple Raffle Smart Contract
 * @author Gabriel Eguiguren P.
 * @notice This contract is for a decentralized raffle.
 * @dev Implements Chainlink VRFv2.5 to get a random winner.
 */
contract Raffle is VRFConsumerBaseV2Plus {
    // Custom errors
    error Raffle__NotEnoughEthToEnter();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

    //Type Declarations
    enum RaffleState {
        OPEN,
        CALCULATING_WINNER
    }

    // State variables
    uint16 private constant REQUEST_CONFIRMATIONS = 1; //how many blocks you wait
    uint32 private constant NUM_WORDS = 1; // number of ramdoms per request
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_intervalDuration; //duration of Lottery interval in seconds
    address private immutable i_owner;
    bytes32 private immutable i_keyHashGasAdd; //chainlink depending on the speed and cost
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint256 private s_lastTimeStamp;
    address payable[] private s_players; // must be payable to payback the winner
    address private s_recentWinner;
    RaffleState private s_raffleState;
    // Events
    event RafflePlayerEntered(address indexed player); // will be stored to logs
    event WinnerPicked(address indexed winner);
    event RequestRaffleWinner(uint256 indexed requestId);

    constructor( uint256 _entranceFee, uint256 _intervalDuration,
        address _vrfCoordinator, bytes32 _keyHashGasAddress,
        uint256 _subscriptionId, uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_owner = msg.sender;
        i_entranceFee = _entranceFee;
        i_intervalDuration = _intervalDuration;
        i_keyHashGasAdd = _keyHashGasAddress;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, Raffle_NotEnoughEth());  //^0.8.26
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthToEnter(); // More gas efficient
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        //emit triggers the event
        emit RafflePlayerEntered(msg.sender);
    }

    // When should the winner be picked?
    /**
     * @dev This is the function that the Chainlink Automation nodes will call to see
     * if the lottery is ready to have a winner picked.
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Implicitly, your subscription has LINK
     * @param - ignored
     * @return upkeepNeeded - true if it's time to pick a winner and restart the lottery
     * @return - ignored
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_intervalDuration;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasPlayers && hasBalance);
        return (upkeepNeeded, "");
    }

    // Start the picking a Winner if conditions met, 
    // This is the function that the Chainlink AUTOMATION nodes will call
    function performUpkeep(bytes calldata /* performData */ ) external { // This function is called by the Chainlink Automation nodes
        // If enough time has passed pick a winner
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING_WINNER;
        // 1. Select a random winner using Chainlink VRFv2.5
        // 1.1 Request Chainlink to generate the random number
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHashGasAdd,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });
        // Will revert if subscription is not set and funded.
        //s_vrfCoordinator is defined in VRFConsumerBaseV2Plus
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestRaffleWinner(requestId);
    }

    // defined as virtual in the abstract parent class
    // must be implemented by the inheriting contract VRFConsumerBaseV2Plus
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal virtual override {
        // CEI Pattern for Smart Contracts: Check, Effect, Interact Prevents Reentrancy Attacks
        // 1. Checks

        // 2. Effects
        // with the random operation module, select the winner
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;

        // Reset data for a new raffle
        s_players = new address payable[](0); // empty the last players lottery array
        s_lastTimeStamp = block.timestamp; // reset the timer
        s_raffleState = RaffleState.OPEN;
        emit WinnerPicked(winner);

        // 3. Interactions (External contract calls)
        // give the winner the total value of the contract and send to it
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert("Raffle__TransferFailed");
        }
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getInterval() external view returns (uint256) {
        return i_intervalDuration;
    }

    function getPlayer(uint256 _index) external view returns (address) {
        return s_players[_index];
    }

    function getNumberOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
