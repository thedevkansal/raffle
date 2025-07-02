// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

error HelperConfig__InvalidChainID(uint256 chainID);

abstract contract CodeConstants {
    // Constants for VRF Coordinator and LINK Token
    uint96 public constant MOCK_BASE_FEE = 0.0001 ether;
    uint96 public constant MOCK_GAS_PRICE = 0.0001 ether;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 1e18; // 1 LINK = 1e9 wei

    // Constants for Chain IDs
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
}

contract HelperConfig is Script, CodeConstants {
    // Struct to hold network configuration
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        bytes32 keyHash;
        address vrfCoordinator;
        address linkToken;
        address account;
    }

    // This will be set when deployed on a local network
    NetworkConfig public localNetworkConfig;
    // Mapping to hold network configurations by chain ID
    mapping(uint256 chainID => NetworkConfig) public networkConfigs;

    // Constructor to initialize network configurations
    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
    }
    //didn't add the local network config in the constructor because it will deployed for no reason

    /**
     * @notice Returns the network configuration for the current chain ID.
     * @dev Throws an error if the chain ID is not supported.
     * @return NetworkConfig The configuration for the current chain ID.
     */
    function getConfigByChainID(uint256 chainID) public returns (NetworkConfig memory) {
        console2.log("Fetching config for chainID: %s", block.chainid);
        if (networkConfigs[chainID].vrfCoordinator != address(0)) {
            return networkConfigs[chainID];
        } else if (chainID == LOCAL_CHAIN_ID) {
            return getOrCreateLocalConfig();
        } else {
            revert HelperConfig__InvalidChainID(chainID);
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            callbackGasLimit: 500000,
            // subscriptionId: 0, // If left as 0, our scripts will create one!
            subscriptionId: 56366666119855030900385025988053281014962739498258270886678512497083887099238,
            // this subscription was created on chainlink vrf but giving errors idk why uint64 Vs uint256 shit
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // Sepolia keyHash
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // Sepolia VRF Coordinator address
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // Sepolia LINK Token address
            account: 0x2780E5a97166BaEE7122D15AD5C779612613A34F //My account on Metamask
        });
    }

    // these paramaters are derived from docs.chain.link/

    function getMainnetEthConfig() public pure returns (NetworkConfig memory mainnetNetworkConfig) {
        mainnetNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            callbackGasLimit: 500000,
            subscriptionId: 0,
            keyHash: 0x3fd2fec10d06ee8f65e7f2e95f5c56511359ece3f33960ad8a866ae24a8ff10b,
            vrfCoordinator: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a,
            linkToken: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            account: 0x2780E5a97166BaEE7122D15AD5C779612613A34F
        });
    }

    /**
     * @notice Deploys a mock VRF Coordinator and Link Token for local testing.
     * @dev This function is called when the local network configuration is not set.
     * @return NetworkConfig The configuration for the local network.
     */
    function getOrCreateLocalConfig() public returns (NetworkConfig memory) {
        // If the local network config is already set, return it
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // Deploy the mock VRF Coordinator and Link Token
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, MOCK_WEI_PER_UNIT_LINK);
        // Create a new Link Token instance
        LinkToken linkToken = new LinkToken();
        // Create a subscription on the mock VRF Coordinator
        uint256 subscriptionId = vrfCoordinatorMock.createSubscription();
        vm.stopBroadcast();

        console2.log("Deployed Mock VRF Coordinator at:", address(vrfCoordinatorMock));
        console2.log("Deployed LinkToken at:", address(linkToken));
        console2.log("Created subscription ID:", subscriptionId);

        // Set the local network configuration
        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            callbackGasLimit: 500000,
            subscriptionId: subscriptionId, // the mock VRFCoordinator's subscription ID
            keyHash: bytes32(uint256(123)), // dummy non-zero keyHash
            vrfCoordinator: address(vrfCoordinatorMock), // Mock VRF Coordinator address
            linkToken: address(linkToken), // Mock Link Token address
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 //Foundry Default account
        });

        return localNetworkConfig;
    }

    // Getter functions for network configuration
    function getVRFCoordinator() public returns (address) {
        return getConfigByChainID(block.chainid).vrfCoordinator;
    }

    function getAccount() public returns (address) {
        return getConfigByChainID(block.chainid).account;
    }

    function getLink() public returns (address) {
        return getConfigByChainID(block.chainid).linkToken;
    }

    function getSubscriptionId() public returns (uint256) {
        return getConfigByChainID(block.chainid).subscriptionId;
    }
}
