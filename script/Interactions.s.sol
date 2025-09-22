// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

/**
 * @title CreateSubscriptionID to VRF on proper Network
 * @author Gabriel Eguiguren P.
 */
contract CreateSubscription is Script {
    function run() public {
        createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address){
        
        // all the relevant data is obtained from HelperConfig.s.sol
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        //owner of contract and subscriptionID in Chainlink VRF coordinator
        address accountOwner = helperConfig.getConfig().accountOwner;   
        (uint256 subId,) = createSubscription(vrfCoordinator, accountOwner);
        return (subId, vrfCoordinator);      
    }

    function createSubscription(address vrfCoordinator, address accountOwner) public returns(uint256, address){
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(accountOwner);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Please update the subscriptionId in HelperConfig.s.sol with this value: ", subId);
        return (subId, vrfCoordinator);
    }
}

/**
 * @title FundSubscription to VRF on proper Network
 * @notice This script will fund programatically the subscription with LINK.
 */
contract FundSubscription is Script, CodeConstants {
    
    uint256 public constant FUND_AMOUNT = 1e18;  // in this case 1 LINK
    
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().linkERC20Address;
        //owner of contract and subscriptionID in Chainlink VRF coordinator
        address accountOwner = helperConfig.getConfig().accountOwner;

        fundSubscription(vrfCoordinator, subId, linkToken, accountOwner);
    }

    function fundSubscription(address vrfCoordinator, uint256 subId, address linkToken, address accountOwner) public {
        console.log("Funding subscription ", subId, " on chainId: ", block.chainid);
        if(block.chainid == LOCAL_CHAIN_ID){
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT * 10);
            vm.stopBroadcast();
        } else {
            console.log("Balance: ", LinkToken(linkToken).balanceOf(accountOwner));
            console.log("Address: ", accountOwner);
            // Fund the subscription with LINK in Sepolia
            vm.startBroadcast(accountOwner);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }
    function run() public {
        fundSubscriptionUsingConfig();
    }   
}
/**
 * @title AddConsumer to VRF on proper Network
 * @notice This script will add via coding a consumer to the VRF subscription.
 */
contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinator;
        address accountOwner = helperConfig.getConfig().accountOwner;

        addConsumer(mostRecentlyDeployed, vrfCoordinatorV2_5, subId, accountOwner);
    }

    // Set the Raffle deployed contract as consumer of the suscriptionId in Chainlink VRF coordinator
    function addConsumer(
            address contractToAddToVrf, 
            address vrfCoordinator, 
            uint256 subId,
            address accountOwner
       ) public {
        console.log("Adding contract consumer to VRF Chainlink coordinator: ", contractToAddToVrf);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        vm.startBroadcast(accountOwner);
        // The final call to Chainlink to add the consumer
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function run() external {
        // get the contract addres of the last local deployed contract
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}


