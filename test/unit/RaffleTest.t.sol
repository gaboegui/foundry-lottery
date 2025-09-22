// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
//import {console} from "forge-std/console.sol";


contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 intervalDuration;
    address vrfCoordinator;
    bytes32 keyHashGasAddress;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 1 ether;

    // Copy pasted Events from Raffle.sol
    event RafflePlayerEntered(address indexed player); // will be stored to logs
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        intervalDuration = config.intervalDuration;
        vrfCoordinator = config.vrfCoordinator;
        keyHashGasAddress = config.keyHashGasAddress;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        // adds the balance to the player
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    } 

    function testPlayerCanEnterRaffle() public {
        vm.prank(PLAYER); // To simulate the next transaction being sent from the specified address.
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffleRevertWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        
        vm.expectRevert(Raffle.Raffle__NotEnoughEthToEnter.selector);
        raffle.enterRaffle(); // sending 0 ether
    }

    function testRaffleRecordPlayerWhenEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        //Arrange
        vm.prank(PLAYER);
        //Act 
        vm.expectEmit(true, false, false, false, address(raffle)); // the 3 first bool are for indexed parameters
        emit RafflePlayerEntered(PLAYER);
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + intervalDuration +1); // advance the time
        vm.roll(block.number +1); // one block has been mined
        raffle.performUpkeep("");
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + intervalDuration +1); // advance the time
        vm.roll(block.number +1); 
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert   
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {

        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + intervalDuration +1); // advance the time
        vm.roll(block.number +1); // REQUEST_CONFIRMATIONS = 2; -> how many blocks you wait to confirm
        raffle.performUpkeep(""); // sets the state to calculating
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == false);
    }

   // 1. has balance, 2. time passed, 3. isOpen, 4. has players
   modifier raffleEnteredConditionsMet {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + intervalDuration +1); // advance the time
        vm.roll(block.number +2);
        _;
    }

     function testCheckUpkeepReturnsTrueWhenAllConditionsAreMet() public raffleEnteredConditionsMet { 
        // Arrange
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == true);
     }

    // performUnkeep Tests
    function testPerformUpkeepRunsIfUpkeepNeededIsTrue() public raffleEnteredConditionsMet {
        // Arrange: all conditionsMet
        // Act
        raffle.performUpkeep("");
        // Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING_WINNER);
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance =0;
        uint256 numplayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // Act / Assert
        vm.expectRevert(
            // abi.encodeWithSelector becuase the custom error has parameters
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numplayers, raffleState)
        );
        raffle.performUpkeep("");
    }

    // Alternative: Instead of expectEvent, we are going to read the Logs
    function testPerformUpkeepAndEmitRequestRaffleWinnerEvent() public raffleEnteredConditionsMet {
        // Arrange: conditionsMet

        // Act
        vm.recordLogs();
        // If the winner is chosen it must trigger event RequestRaffleWinner(requestId) and write in Logs
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        // The first log is from the `RafflePlayerEntered` event, the second is from the `RequestedRaffleWinner` event
        bytes32 requestId = logs[1].topics[1];

        // Assert
        assert(uint256(requestId) > 0);
    }
    
    // This modifier is used to skip tests when running on a forked network.
    // We skip because we are using a VRFCoordinatorV2_5Mock object instead of real Blockchain
    modifier skipForkTest(){
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    // number of Fuzzy tests that varies randomRequestId definied in foundry.toml [fuzz] section
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public 
        raffleEnteredConditionsMet skipForkTest {
        // Arrange /Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    // Test the complete process of the Raffle
    function testFulfillRandomWordsPicksAWinnerAndResetsAndSendMoney() public 
        raffleEnteredConditionsMet skipForkTest {
        // Arrange
        
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1; // because the PLAYER is already entered

        for (uint256 i = startingIndex; i < additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        //uint256 prizePool = raffle.getEntranceFee() * additionalEntrants;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emit RequestId
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address winner = raffle.getRecentWinner();
        uint256 winnerBalance = winner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        //console.log("balance: ", winnerBalance, "prizePool:", prizePool, "starting balance: ", STARTING_PLAYER_BALANCE);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(winnerBalance > STARTING_PLAYER_BALANCE );
        assert(endingTimeStamp > startingTimeStamp);

    } 

}     