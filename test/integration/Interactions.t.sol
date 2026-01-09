// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/raffle.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../mocks/LinkToken.sol";

contract InteractionTest is Test, CodeConstants {
    //Interactions test
    /* To check whether the Deploy, the helper and the interactions work as intended */
    DeployRaffle deployer;
    HelperConfig helperConfig;
    address vrfCoordinator;
    uint256 subscriptionId;
    Raffle raffle;
    VRFCoordinatorV2_5Mock vrfCoordinatorMock;
    LinkToken link;

    function setUp() external {
        helperConfig = new HelperConfig();
        link = new LinkToken();
    }

    function testGetConfigGetsLocalTestConfig() public {
        HelperConfig.NetworkConfig memory testConfig = helperConfig.getOrCreateAnvilEthConfig();
        assertEq(testConfig.entranceFee, 0.01 ether);
        assertEq(testConfig.interval, 30);
        assertEq(testConfig.gasLane, 0x474e34a077df58807dbe9c96d3c009b23b3c9967a84bb82552e0606a50eb6ae7);
        assertEq(testConfig.callbackGasLimit, 500000);
        assertEq(testConfig.account, FOUNDRY_DEFAULT_SENDER);
    }

    function testGetConfigGetsSepoliaConfig() public view {
        HelperConfig.NetworkConfig memory testConfig = helperConfig.getSepoliaEthConfig();
        assertEq(testConfig.entranceFee, 0.01 ether);
        assertEq(testConfig.interval, 30);
        assertEq(testConfig.vrfCoordinator, 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
        assertEq(testConfig.gasLane, 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae);
        assertEq(
            testConfig.subscriptionId, 13923162593926272364056570280401826963723594188384330222537098400530328953968
        );
        assertEq(testConfig.callbackGasLimit, 500000);
        assertEq(testConfig.link, 0x779877A7B0D9E8603169DdbD7836e478b4624789);
        assertEq(testConfig.account, 0xc76e59d76721987A46dE15f392dF50114382bF4B);
    }

    function testGetConfigGetsTheRightConfigBasedOnChainIdAnvil() public {
        vm.chainId(LOCAL_CHAIN_ID);
        HelperConfig.NetworkConfig memory testConfig = helperConfig.getConfig();
        assertEq(testConfig.entranceFee, 0.01 ether);
        assertEq(testConfig.interval, 30);
        assertEq(testConfig.gasLane, 0x474e34a077df58807dbe9c96d3c009b23b3c9967a84bb82552e0606a50eb6ae7);
        assertEq(testConfig.callbackGasLimit, 500000);
        assertEq(testConfig.account, FOUNDRY_DEFAULT_SENDER);
    }

    function testGetConfigGetsTheRightConfigBasedOnChainIdSepolia() public {
        vm.chainId(ETH_SEPOLIA_CHAIN_ID);
        HelperConfig.NetworkConfig memory testConfig = helperConfig.getConfig();
        assertEq(testConfig.entranceFee, 0.01 ether);
        assertEq(testConfig.interval, 30);
        assertEq(testConfig.vrfCoordinator, 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
        assertEq(testConfig.gasLane, 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae);
        assertEq(
            testConfig.subscriptionId, 13923162593926272364056570280401826963723594188384330222537098400530328953968
        );
        assertEq(testConfig.callbackGasLimit, 500000);
        assertEq(testConfig.link, 0x779877A7B0D9E8603169DdbD7836e478b4624789);
        assertEq(testConfig.account, 0xc76e59d76721987A46dE15f392dF50114382bF4B);
    }

    function testDeployScriptDeploysAndRegistersConsumerOnLocal() public {
        vm.chainId(LOCAL_CHAIN_ID);
        deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);

        assertGt(address(raffle).code.length, 0);
        assertTrue(coordinator.consumerIsAdded(config.subscriptionId, address(raffle)));
    }

    function testCreateSubscriptionScriptCreatesSubscription() public {
        vm.chainId(LOCAL_CHAIN_ID);
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        CreateSubscription creator = new CreateSubscription();

        (uint256 subId, address coordinator) = creator.createSubscription(config.vrfCoordinator, config.account);

        (, , , address owner,) = VRFCoordinatorV2_5Mock(coordinator).getSubscription(subId);
        assertEq(owner, config.account);
    }

    function testFundSubscriptionScriptFundsLocalSubscription() public {
        vm.chainId(LOCAL_CHAIN_ID);
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);
        FundSubscription funder = new FundSubscription();

        (uint96 balanceBefore,, , ,) = coordinator.getSubscription(config.subscriptionId);
        funder.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);
        (uint96 balanceAfter,, , ,) = coordinator.getSubscription(config.subscriptionId);

        assertEq(balanceAfter, balanceBefore + uint96(funder.FUND_AMOUNT()));
    }

    function testAddConsumerScriptAddsConsumer() public {
        vm.chainId(LOCAL_CHAIN_ID);
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);
        AddConsumer adder = new AddConsumer();
        Raffle localRaffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );

        adder.addConsumer(address(localRaffle), config.vrfCoordinator, config.subscriptionId, config.account);

        assertTrue(coordinator.consumerIsAdded(config.subscriptionId, address(localRaffle)));
    }
}
