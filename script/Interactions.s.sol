//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract CreateSubscription is Script, CodeConstants {
    /**
     * @notice Creates a Chainlink VRF subscription using the configuration from HelperConfig.
     * @dev This function deploys a new HelperConfig contract to get the VRF Coordinator and account.
     * @return subscriptionId The ID of the created subscription.
     * @return vrfCoordinator The address of the VRF Coordinator.
     */
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getVRFCoordinator();
        address account = helperConfig.getAccount();
        return createSubscription(vrfCoordinator, account);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
        console2.log("Creating subscription on chainID: %s", block.chainid);

        // If the chain ID is local, create a subscription using the mock VRF Coordinator
        // Otherwise, use the VRF Coordinator interface to create a subscription
        uint256 subscriptionId;
        vm.startBroadcast(account);
        if (block.chainid == LOCAL_CHAIN_ID) {
            subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        } else {
            subscriptionId = VRFCoordinatorV2Interface(vrfCoordinator).createSubscription();
        }
        vm.stopBroadcast();

        console2.log("Subscription created with ID: %s", subscriptionId);
        console2.log("please update the subscription ID in the HelperConfig contract");
        return (subscriptionId, vrfCoordinator);
    }

    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint96 constant FUND_AMOUNT = 1 ether;

    /**
     * @notice Funds a Chainlink VRF subscription using the configuration from HelperConfig.
     * @dev This function deploys a new HelperConfig contract to get the VRF Coordinator, subscription ID, and account.
     */
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getVRFCoordinator();
        uint256 subId = helperConfig.getSubscriptionId();
        address account = helperConfig.getAccount();
        address linkToken = helperConfig.getLink();

        // If the subscription ID is 0, create a new subscription and update the vrfCoordinator address
        if (subId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (uint256 updatedSubId, address updatedVRF) = createSub.run();
            subId = updatedSubId;
            vrfCoordinator = updatedVRF;
            console2.log("New SubId Created! ", subId, "VRF Address: ", vrfCoordinator);
        }
        return fundSubscription(vrfCoordinator, subId, linkToken, account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subID, address linkToken, address account) public {
        console2.log("Funding subscription on subID: %s", subID);
        console2.log("Using VRF Coordinator: %s", vrfCoordinator);
        console2.log("On chainID: %s", block.chainid);

        // If the chain ID is local, fund the subscription using the mock VRF Coordinator
        // Otherwise, fund it using the Link Token contract
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subID, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(uint64(subID)));
            vm.stopBroadcast();
        }
    }

    function run() external {
        return fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script, CodeConstants {
    /**
     * @notice Adds a consumer contract to a Chainlink VRF subscription using the configuration from HelperConfig.
     * @dev This function deploys a new HelperConfig contract to get the VRF Coordinator, subscription ID, and account.
     * @param mostrecentdeployedRaffle The address of the most recently deployed Raffle contract.
     */
    function addConsumerUsingConfig(address mostrecentdeployedRaffle) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getVRFCoordinator();
        uint256 subID = helperConfig.getSubscriptionId();
        address account = helperConfig.getAccount();

        return addConsumer(vrfCoordinator, subID, mostrecentdeployedRaffle, account);
    }

    function addConsumer(address vrfCoordinator, uint256 subID, address raffle, address account) public {
        console2.log("Adding consumer contract: %s", raffle);
        console2.log("Adding consumer to subscription on subID: %s", subID);
        console2.log("Using VRF Coordinator: %s", vrfCoordinator);
        console2.log("On chainID: %s", block.chainid);

        require(subID != 0, "Subscription ID cannot be zero");

        console2.log("uint256 subID:", subID);
        console2.log("uint64 subID:", uint64(subID));

        // If the chain ID is local, add the consumer using the mock VRF Coordinator
        // Otherwise, use the VRF Coordinator interface to add the consumer
        vm.startBroadcast(account);
        if (block.chainid == LOCAL_CHAIN_ID) {
            VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subID, raffle);
        } else {
            VRFCoordinatorV2Interface(vrfCoordinator).addConsumer(uint64(subID), raffle);
        }
        vm.stopBroadcast();
    }

    function run() external {
        address mostrecentDeployedRaffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostrecentDeployedRaffle);
    }
}
