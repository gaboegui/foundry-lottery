// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {

    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if(config.subscriptionId == 0){
            // Creating the subscriptionId in the respective Blockchain
            CreateSubscription createSubIdContract = new CreateSubscription();
            (config.subscriptionId,) = createSubIdContract.createSubscription(config.vrfCoordinator,
                 config.accountOwner);

            // Fund the subscription with LINK for allowing it to request random words
            FundSubscription fundSubIdContract = new FundSubscription();
            fundSubIdContract.fundSubscription(config.vrfCoordinator, config.subscriptionId,
                 config.linkERC20Address, config.accountOwner);
        }
        // deploy the contract
        vm.startBroadcast(config.accountOwner);
        Raffle raffle = new Raffle(
            config.entranceFee, 
            config.intervalDuration, 
            config.vrfCoordinator, 
            config.keyHashGasAddress, 
            config.subscriptionId, 
            config.callbackGasLimit);
        vm.stopBroadcast();

        // Add Consumer to Chainlink VRF coordinator
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator,
            config.subscriptionId, config.accountOwner);
        return (raffle, helperConfig);
    }
}


