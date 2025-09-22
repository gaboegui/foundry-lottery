// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";


abstract contract CodeConstants {
    
    uint96 public constant TICKET_RAFFLE_ENTRANCE_FEE = 0.001 ether; // 1e15 wei aprox $4.5
    uint256 public constant RAFFLE_TIME_DURATION_INTERVAL = 3600; // seconds = 1Hour
    
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    // VRF Mock values for constructor
    uint96 public constant MOCK_BASE_FEE = 0.002 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 2e15; // 1 LINK 
}
/**
 * @title HelperConfig
 * @author Gabriel Eguiguren P.
 * @dev Helper to return different configuration for different blockchains
 */
contract HelperConfig is CodeConstants, Script {

    error HelperConfig__InvalidChainId(uint256 chainId);
    
    struct NetworkConfig{
        uint256 entranceFee;
        uint256 intervalDuration;
        address vrfCoordinator;
        bytes32 keyHashGasAddress;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address linkERC20Address;
        address accountOwner;
    }

    NetworkConfig public localNetworkConfig;
    mapping (uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() public {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaNetworkConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
        return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilLocalEthConfig();
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    // Creates Config for Local Blockchain
    function getOrCreateAnvilLocalEthConfig() public returns (NetworkConfig memory) {
        // already exists
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        } 

        // deploy VRFCoordinatorV2_5Mock
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock 
            = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, MOCK_WEI_PER_UNIT_LINK);
        // Create fake LINK token
        LinkToken linkToken = new LinkToken();

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: TICKET_RAFFLE_ENTRANCE_FEE,
            intervalDuration: RAFFLE_TIME_DURATION_INTERVAL,
            vrfCoordinator: address(vrfCoordinatorMock), 
            // dont matter for local
            keyHashGasAddress: 0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            linkERC20Address: address(linkToken),
            accountOwner: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 // comes as default from Base.sol
            
        });

        return localNetworkConfig;
    }

    /**
     * @dev all values are obtained from Chainlink and Sepolia testnet
     * @notice This function returns the NetworkConfig for Sepolia testnet. 
     */
    function getSepoliaNetworkConfig() public pure returns (NetworkConfig memory) {
        
        return NetworkConfig({
            entranceFee: TICKET_RAFFLE_ENTRANCE_FEE, 
            intervalDuration: RAFFLE_TIME_DURATION_INTERVAL,
            // https://docs.chain.link/vrf/v2-5/supported-networks
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, 
            keyHashGasAddress: 0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71,
            //https://vrf.chain.link/#/side-drawer/subscription/sepolia/114106273471514191118470810364804629509721860383853023365763283285247998828867
            subscriptionId: 114106273471514191118470810364804629509721860383853023365763283285247998828867, 
            callbackGasLimit: 500000,
            linkERC20Address: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            accountOwner: 0x30B48891E399Df43EF594D7a6b225bc3f8c80049 // This account created the subscriptionId in Chainlink
        });
    }
}