//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script{

    function run() public {
        deployRaffle();
    }
    event RaffleDeployed(address indexed raffleAddress, uint256 subscriptionId);

    function deployRaffle() public returns (Raffle , HelperConfig) {

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainID(block.chainid);

        // If the subscriptionId is 0, it means we need to create a new subscription
        if (config.subscriptionId == 0) {
            //create a subscription if it doesn't exist
            CreateSubscription createSub = new CreateSubscription();
            (config.subscriptionId,config.vrfCoordinator) = 
                createSub.createSubscription(config.vrfCoordinator, config.account);
            //fund the subscription
            FundSubscription fundSub = new FundSubscription();
            fundSub.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.linkToken, config.account);
        }

        require(config.vrfCoordinator != address(0), "Invalid VRF Coordinator");
        
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.keyHash,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        emit RaffleDeployed(address(raffle), config.subscriptionId);

        // Add the raffle as a consumer to the VRF Coordinator
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(config.vrfCoordinator, config.subscriptionId, address(raffle), config.account);

        return (raffle, helperConfig);
    }
}