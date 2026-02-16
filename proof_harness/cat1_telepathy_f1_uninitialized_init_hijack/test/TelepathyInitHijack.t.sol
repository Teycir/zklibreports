// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    AttestationGatewayModel,
    AttestationResponse,
    AttestationVerifierModel,
    AlwaysFalseVerifier,
    AlwaysTrueVerifier,
    MessageCodec,
    MinimalHandler,
    PlainHandler,
    TelepathyRouterV2Model,
    VerifierType
} from "../src/TelepathyInitHijackHarness.sol";

contract Actor {
    function initializeRouter(
        TelepathyRouterV2Model router,
        bool sendingEnabled,
        bool executingEnabled,
        address feeVault,
        address timelock,
        address guardian
    ) external returns (bool) {
        (bool success,) = address(router).call(
            abi.encodeWithSelector(
                router.initialize.selector,
                sendingEnabled,
                executingEnabled,
                feeVault,
                timelock,
                guardian
            )
        );
        return success;
    }

    function setDefaultVerifier(
        TelepathyRouterV2Model router,
        VerifierType verifierType,
        address verifier
    ) external returns (bool) {
        (bool success,) = address(router).call(
            abi.encodeWithSelector(router.setDefaultVerifier.selector, verifierType, verifier)
        );
        return success;
    }

    function setZkRelayer(TelepathyRouterV2Model router, address relayer, bool enabled)
        external
        returns (bool)
    {
        (bool success,) =
            address(router).call(abi.encodeWithSelector(router.setZkRelayer.selector, relayer, enabled));
        return success;
    }

    function execute(TelepathyRouterV2Model router, bytes memory proofData, bytes memory message)
        external
        returns (bool)
    {
        (bool success,) =
            address(router).call(abi.encodeWithSelector(router.execute.selector, proofData, message));
        return success;
    }
}

contract TelepathyInitHijackTest {
    using MessageCodec for bytes;
    uint8 internal constant ROUTER_VERSION = 2;

    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    function _message(
        uint64 nonce,
        uint32 sourceChainId,
        address sourceAddress,
        address destinationAddress,
        bytes memory data
    ) internal view returns (bytes memory) {
        return MessageCodec.encode(
            ROUTER_VERSION,
            nonce,
            sourceChainId,
            sourceAddress,
            uint32(block.chainid),
            destinationAddress,
            data
        );
    }

    function _setupAttestationRouter()
        internal
        returns (TelepathyRouterV2Model router, Actor attacker, AttestationGatewayModel gateway)
    {
        router = new TelepathyRouterV2Model();
        Actor trustedTimelock = new Actor();
        Actor trustedGuardian = new Actor();
        attacker = new Actor();

        _assertTrue(
            trustedTimelock.initializeRouter(
                router, true, true, address(0), address(trustedTimelock), address(trustedGuardian)
            ),
            "trusted initialize should succeed"
        );

        gateway = new AttestationGatewayModel();
        uint32[] memory sourceChains = new uint32[](1);
        sourceChains[0] = 42161;
        address[] memory sourceRouters = new address[](1);
        sourceRouters[0] = address(0x1111111111111111111111111111111111111111);
        AttestationVerifierModel verifier =
            new AttestationVerifierModel(address(gateway), sourceChains, sourceRouters);

        _assertTrue(
            trustedTimelock.setDefaultVerifier(
                router, VerifierType.ATTESTATION_STATE_QUERY, address(verifier)
            ),
            "attestation verifier should be set"
        );
    }

    /// @notice F1 witness:
    /// if proxy is left uninitialized, first caller can seize timelock/guardian roles and
    /// configure malicious verifier routing to execute forged messages.
    function test_f1_bug_model_uninitialized_first_caller_seizes_roles_and_executes_forged_message()
        public
    {
        TelepathyRouterV2Model router = new TelepathyRouterV2Model();
        Actor attacker = new Actor();
        Actor deployer = new Actor();

        bool attackerInitialized =
            attacker.initializeRouter(router, true, true, address(0), address(attacker), address(attacker));
        _assertTrue(attackerInitialized, "attacker should initialize first");
        _assertTrue(router.timelock() == address(attacker), "attacker should control timelock");
        _assertTrue(router.guardian() == address(attacker), "attacker should control guardian");

        bool deployerInitLater =
            deployer.initializeRouter(router, true, true, address(0), address(deployer), address(deployer));
        _assertTrue(!deployerInitLater, "deployer second initialize must fail");

        AlwaysTrueVerifier alwaysTrue = new AlwaysTrueVerifier();
        bool setVerifier = attacker.setDefaultVerifier(
            router, VerifierType.ATTESTATION_STATE_QUERY, address(alwaysTrue)
        );
        _assertTrue(setVerifier, "attacker timelock should set verifier");

        MinimalHandler handler =
            new MinimalHandler(address(router), VerifierType.ATTESTATION_STATE_QUERY);
        bytes memory forged = _message(
            1,
            42161,
            address(0xBADC0DE),
            address(handler),
            abi.encodePacked("forged-payload")
        );

        bool executed = attacker.execute(router, hex"", forged);
        _assertTrue(executed, "forged message should execute under hijacked verifier control");
        _assertTrue(handler.calls() == 1, "handler should be called exactly once");
        _assertTrue(handler.lastSourceChain() == 42161, "forged source chain should be accepted");
        _assertTrue(handler.lastSourceAddress() == address(0xBADC0DE), "forged source should be accepted");
    }

    /// @notice Fixed control: trusted first initializer owns privileged roles, blocking takeover.
    function test_f1_fixed_model_trusted_first_initialize_blocks_role_takeover() public {
        TelepathyRouterV2Model router = new TelepathyRouterV2Model();
        Actor trusted = new Actor();
        Actor guardian = new Actor();
        Actor attacker = new Actor();

        bool trustedInit =
            trusted.initializeRouter(router, true, true, address(0), address(trusted), address(guardian));
        _assertTrue(trustedInit, "trusted initialize should succeed");

        bool attackerSecondInit =
            attacker.initializeRouter(router, true, true, address(0), address(attacker), address(attacker));
        _assertTrue(!attackerSecondInit, "attacker cannot initialize after trusted init");
        _assertTrue(router.timelock() == address(trusted), "timelock should remain trusted");
        _assertTrue(router.guardian() == address(guardian), "guardian should remain trusted");
    }

    /// @notice Fixed control witness:
    /// non-timelock attacker cannot set verifier and cannot execute forged message.
    function test_f1_fixed_model_non_timelock_cannot_enable_forged_execute() public {
        TelepathyRouterV2Model router = new TelepathyRouterV2Model();
        Actor trustedTimelock = new Actor();
        Actor trustedGuardian = new Actor();
        Actor attacker = new Actor();

        bool trustedInit = trustedTimelock.initializeRouter(
            router, true, true, address(0), address(trustedTimelock), address(trustedGuardian)
        );
        _assertTrue(trustedInit, "trusted initialize should succeed");

        AlwaysTrueVerifier alwaysTrue = new AlwaysTrueVerifier();
        bool attackerSetTrue = attacker.setDefaultVerifier(
            router, VerifierType.ATTESTATION_STATE_QUERY, address(alwaysTrue)
        );
        _assertTrue(!attackerSetTrue, "attacker must not set verifier");

        AlwaysFalseVerifier alwaysFalse = new AlwaysFalseVerifier();
        bool trustedSetFalse = trustedTimelock.setDefaultVerifier(
            router, VerifierType.ATTESTATION_STATE_QUERY, address(alwaysFalse)
        );
        _assertTrue(trustedSetFalse, "trusted timelock should set verifier");

        MinimalHandler handler =
            new MinimalHandler(address(router), VerifierType.ATTESTATION_STATE_QUERY);
        bytes memory forged =
            _message(2, 42161, address(0xFACEB00C), address(handler), abi.encodePacked("forged"));

        bool executed = attacker.execute(router, hex"", forged);
        _assertTrue(!executed, "forged execute should fail when verifier remains trusted");
        _assertTrue(handler.calls() == 0, "handler should not be called");
    }

    /// @notice F2 trust-boundary falsification:
    /// if destination contract does not explicitly provide a verifier hint, router falls back
    /// to default verifier and forged execution cannot bypass that default policy.
    function test_f2_plain_destination_uses_default_verifier_and_rejects_forged_message() public {
        TelepathyRouterV2Model router = new TelepathyRouterV2Model();
        Actor trustedTimelock = new Actor();
        Actor trustedGuardian = new Actor();
        Actor attacker = new Actor();

        _assertTrue(
            trustedTimelock.initializeRouter(
                router, true, true, address(0), address(trustedTimelock), address(trustedGuardian)
            ),
            "trusted initialize should succeed"
        );
        _assertTrue(
            trustedTimelock.setDefaultVerifier(
                router, VerifierType.ATTESTATION_STATE_QUERY, address(new AlwaysFalseVerifier())
            ),
            "strict default attestation verifier should be set"
        );

        PlainHandler handler = new PlainHandler(address(router));
        bytes memory forged =
            _message(10, 42161, address(0x1234), address(handler), abi.encodePacked("f2-plain"));

        bool executed = attacker.execute(router, hex"", forged);
        _assertTrue(!executed, "forged execute should fail through default verifier");
        _assertTrue(handler.calls() == 0, "plain destination should not be called");
    }

    /// @notice F2 trust-boundary witness:
    /// custom verifier path is only reached when destination contract explicitly opts in
    /// by exposing `verifierType() = CUSTOM` and verifier logic.
    function test_f2_custom_verifier_path_requires_destination_contract_cooperation() public {
        TelepathyRouterV2Model router = new TelepathyRouterV2Model();
        Actor trustedTimelock = new Actor();
        Actor trustedGuardian = new Actor();
        Actor attacker = new Actor();

        _assertTrue(
            trustedTimelock.initializeRouter(
                router, true, true, address(0), address(trustedTimelock), address(trustedGuardian)
            ),
            "trusted initialize should succeed"
        );
        _assertTrue(
            trustedTimelock.setDefaultVerifier(
                router, VerifierType.ATTESTATION_STATE_QUERY, address(new AlwaysFalseVerifier())
            ),
            "strict default verifier should be set"
        );

        MinimalHandler customHandler = new MinimalHandler(address(router), VerifierType.CUSTOM);
        customHandler.setVerifyResult(true);

        bytes memory forged1 = _message(
            11,
            42161,
            address(0xABCD),
            address(customHandler),
            abi.encodePacked("f2-custom-true")
        );
        bool executed1 = attacker.execute(router, hex"", forged1);
        _assertTrue(executed1, "custom destination verifier should allow its own message");
        _assertTrue(customHandler.calls() == 1, "custom destination should be called once");

        customHandler.setVerifyResult(false);
        bytes memory forged2 = _message(
            12,
            42161,
            address(0xABCD),
            address(customHandler),
            abi.encodePacked("f2-custom-false")
        );
        bool executed2 = attacker.execute(router, hex"", forged2);
        _assertTrue(!executed2, "custom destination verifier controls acceptance");
        _assertTrue(customHandler.calls() == 1, "call count should remain unchanged");
    }

    /// @notice F3 falsification:
    /// attestation-mode execution requires gateway response bound to source chain, nonce, and messageId.
    function test_f3_attestation_requires_matching_gateway_response() public {
        (TelepathyRouterV2Model router, Actor attacker, AttestationGatewayModel gateway) =
            _setupAttestationRouter();

        PlainHandler handler = new PlainHandler(address(router));
        bytes memory message =
            _message(33, 42161, address(0xCAFE), address(handler), abi.encodePacked("f3-bound"));

        gateway.setCurrentResponse(
            AttestationResponse({
                chainId: 42161,
                nonce: 34,
                messageId: keccak256(message)
            })
        );
        _assertTrue(!attacker.execute(router, hex"", message), "nonce mismatch must fail");
        _assertTrue(handler.calls() == 0, "handler should not be called on mismatch");

        gateway.setCurrentResponse(
            AttestationResponse({
                chainId: 42161,
                nonce: 33,
                messageId: keccak256(message)
            })
        );
        _assertTrue(attacker.execute(router, hex"", message), "matching response should allow execute");
        _assertTrue(handler.calls() == 1, "handler should be called once");
    }

    /// @notice F3 control:
    /// once executed, replay is blocked even if gateway response remains unchanged.
    function test_f3_attestation_matching_response_still_replay_protected() public {
        (TelepathyRouterV2Model router, Actor attacker, AttestationGatewayModel gateway) =
            _setupAttestationRouter();

        PlainHandler handler = new PlainHandler(address(router));
        bytes memory message =
            _message(44, 42161, address(0xBEEF), address(handler), abi.encodePacked("f3-replay"));

        gateway.setCurrentResponse(
            AttestationResponse({
                chainId: 42161,
                nonce: 44,
                messageId: keccak256(message)
            })
        );
        _assertTrue(attacker.execute(router, hex"", message), "first execute should succeed");
        _assertTrue(!attacker.execute(router, hex"", message), "second execute should fail replay guard");
        _assertTrue(handler.calls() == 1, "handler should only be called once");
    }

    /// @notice Fuzz witness:
    /// after attacker first-initializes and controls verifier + relayer settings,
    /// forged messages across source-chain classes execute successfully.
    function testFuzz_f1_bug_model_attacker_initialized_router_accepts_forged_messages(
        uint64 nonce,
        uint32 sourceChainId,
        bytes calldata payload
    ) public {
        if (payload.length > 128) {
            return;
        }

        TelepathyRouterV2Model router = new TelepathyRouterV2Model();
        Actor attacker = new Actor();

        bool initOk =
            attacker.initializeRouter(router, true, true, address(0), address(attacker), address(attacker));
        _assertTrue(initOk, "attacker should initialize");

        AlwaysTrueVerifier alwaysTrue = new AlwaysTrueVerifier();
        _assertTrue(
            attacker.setDefaultVerifier(router, VerifierType.ATTESTATION_STATE_QUERY, address(alwaysTrue)),
            "set attestation verifier"
        );
        _assertTrue(
            attacker.setDefaultVerifier(router, VerifierType.ZK_EVENT, address(alwaysTrue)),
            "set zk event verifier"
        );
        _assertTrue(
            attacker.setDefaultVerifier(router, VerifierType.ZK_STORAGE, address(alwaysTrue)),
            "set zk storage verifier"
        );
        _assertTrue(
            attacker.setZkRelayer(router, address(attacker), true), "attacker should whitelist self"
        );

        MinimalHandler handler = new MinimalHandler(address(router), VerifierType.NULL);
        bytes memory forged = _message(
            nonce,
            sourceChainId,
            address(uint160(uint256(keccak256(payload)))),
            address(handler),
            payload
        );

        bool executed = attacker.execute(router, hex"", forged);
        _assertTrue(executed, "forged message should execute");
        _assertTrue(handler.calls() == 1, "handler should be called");
    }

    /// @notice Fuzz fixed control:
    /// without attacker-controlled initialization, forged execution cannot be forced.
    function testFuzz_f1_fixed_model_trusted_initialized_router_rejects_attacker_forged_messages(
        uint64 nonce,
        bytes calldata payload
    ) public {
        if (payload.length > 128) {
            return;
        }

        TelepathyRouterV2Model router = new TelepathyRouterV2Model();
        Actor trustedTimelock = new Actor();
        Actor trustedGuardian = new Actor();
        Actor attacker = new Actor();

        _assertTrue(
            trustedTimelock.initializeRouter(
                router, true, true, address(0), address(trustedTimelock), address(trustedGuardian)
            ),
            "trusted initialize should succeed"
        );

        // Trusted timelock keeps verifier strict/false.
        AlwaysFalseVerifier alwaysFalse = new AlwaysFalseVerifier();
        _assertTrue(
            trustedTimelock.setDefaultVerifier(
                router, VerifierType.ATTESTATION_STATE_QUERY, address(alwaysFalse)
            ),
            "trusted verifier set"
        );

        // Attacker cannot alter verifier or guardian whitelist.
        _assertTrue(
            !attacker.setDefaultVerifier(
                router, VerifierType.ATTESTATION_STATE_QUERY, address(new AlwaysTrueVerifier())
            ),
            "attacker must fail verifier update"
        );
        _assertTrue(!attacker.setZkRelayer(router, address(attacker), true), "attacker must fail relayer set");

        MinimalHandler handler =
            new MinimalHandler(address(router), VerifierType.ATTESTATION_STATE_QUERY);
        bytes memory forged =
            _message(nonce, 42161, address(uint160(uint256(keccak256(payload)))), address(handler), payload);

        bool executed = attacker.execute(router, hex"", forged);
        _assertTrue(!executed, "forged message should fail");
        _assertTrue(handler.calls() == 0, "handler should remain untouched");
    }

    /// @notice F3 fuzz falsification:
    /// mismatched attestation response cannot execute.
    function testFuzz_f3_mismatched_attestation_response_cannot_execute(
        uint64 nonce,
        bytes calldata payload,
        bytes32 badMessageId
    ) public {
        if (payload.length > 128) {
            return;
        }

        (TelepathyRouterV2Model router, Actor attacker, AttestationGatewayModel gateway) =
            _setupAttestationRouter();

        PlainHandler handler = new PlainHandler(address(router));
        bytes memory message = _message(
            nonce,
            42161,
            address(uint160(uint256(keccak256(payload)))),
            address(handler),
            payload
        );
        bytes32 messageId = keccak256(message);
        if (badMessageId == messageId) {
            badMessageId = bytes32(uint256(messageId) ^ uint256(1));
        }

        gateway.setCurrentResponse(
            AttestationResponse({
                chainId: 42161,
                nonce: nonce,
                messageId: badMessageId
            })
        );

        bool executed = attacker.execute(router, hex"", message);
        _assertTrue(!executed, "mismatched attestation should fail");
        _assertTrue(handler.calls() == 0, "handler should not be called");
    }
}
