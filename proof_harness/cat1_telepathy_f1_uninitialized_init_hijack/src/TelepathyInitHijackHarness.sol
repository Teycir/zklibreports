// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum VerifierType {
    NULL,
    CUSTOM,
    ZK_EVENT,
    ZK_STORAGE,
    ATTESTATION_STATE_QUERY
}

interface IMessageVerifier {
    function verify(bytes calldata _proofData, bytes calldata _message) external returns (bool);
}

interface ITelepathyHandlerV2 {
    function handleTelepathy(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
        external
        returns (bytes4);
}

interface IVerifierTypeHint {
    function verifierType() external view returns (VerifierType);
}

library MessageCodec {
    struct Envelope {
        uint8 version;
        uint64 nonce;
        uint32 sourceChainId;
        address sourceAddress;
        uint32 destinationChainId;
        address destinationAddress;
        bytes data;
    }

    function encode(
        uint8 _version,
        uint64 _nonce,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint32 _destinationChainId,
        address _destinationAddress,
        bytes memory _data
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                Envelope({
                    version: _version,
                    nonce: _nonce,
                    sourceChainId: _sourceChainId,
                    sourceAddress: _sourceAddress,
                    destinationChainId: _destinationChainId,
                    destinationAddress: _destinationAddress,
                    data: _data
                })
            );
    }

    function decode(bytes memory _message) internal pure returns (Envelope memory) {
        return abi.decode(_message, (Envelope));
    }
}

/// @notice Minimal executable model of TelepathyRouterV2 auth and verifier routing.
///         This model isolates initialization/role takeover and forged execute reachability.
contract TelepathyRouterV2Model {
    using MessageCodec for bytes;

    uint8 public constant VERSION = 2;
    uint32 public constant BROADCAST_ALL_CHAINS = 0;

    bool public initialized;
    bool public executingEnabled;
    address public timelock;
    address public guardian;

    mapping(bytes32 => bool) public executed;
    mapping(VerifierType => address) public defaultVerifiers;
    mapping(address => bool) public zkRelayers;

    error AlreadyInitialized();
    error OnlyTimelock(address sender);
    error OnlyGuardian(address sender);
    error ExecutingDisabled();
    error MessageAlreadyExecuted(bytes32 messageId);
    error MessageNotForChain(bytes32 messageId, uint32 destinationChainId, uint32 currentChainId);
    error MessageWrongVersion(bytes32 messageId, uint8 messageVersion, uint8 currentVersion);
    error VerifierNotFound(uint256 verifierType);
    error NotZkRelayer(address sender);
    error VerificationFailed();
    error CallFailed();
    error InvalidSelector();

    modifier onlyTimelock() {
        if (msg.sender != timelock) {
            revert OnlyTimelock(msg.sender);
        }
        _;
    }

    modifier onlyGuardian() {
        if (msg.sender != guardian) {
            revert OnlyGuardian(msg.sender);
        }
        _;
    }

    /// @dev Mirrors open initializer semantics: first caller wins if proxy is uninitialized.
    function initialize(
        bool,
        bool _executingEnabled,
        address,
        address _timelock,
        address _guardian
    ) external {
        if (initialized) {
            revert AlreadyInitialized();
        }
        initialized = true;
        executingEnabled = _executingEnabled;
        timelock = _timelock;
        guardian = _guardian;
    }

    function setDefaultVerifier(VerifierType _verifierType, address _verifier) external onlyTimelock {
        defaultVerifiers[_verifierType] = _verifier;
    }

    function setZkRelayer(address _zkRelayer, bool _enabled) external onlyGuardian {
        zkRelayers[_zkRelayer] = _enabled;
    }

    function getVerifierType(bytes memory _message) public view returns (VerifierType) {
        MessageCodec.Envelope memory env = _message.decode();
        try IVerifierTypeHint(env.destinationAddress).verifierType() returns (VerifierType hinted) {
            if (hinted != VerifierType.NULL) {
                return hinted;
            }
        } catch {}

        if (env.sourceChainId == 1 || env.sourceChainId == 5 || env.sourceChainId == 100) {
            return VerifierType.ZK_EVENT;
        }
        return VerifierType.ATTESTATION_STATE_QUERY;
    }

    function execute(bytes calldata _proofData, bytes calldata _message) external {
        if (!executingEnabled) {
            revert ExecutingDisabled();
        }

        MessageCodec.Envelope memory env = _message.decode();
        bytes32 messageId = keccak256(_message);

        if (executed[messageId]) {
            revert MessageAlreadyExecuted(messageId);
        }
        if (
            env.destinationChainId != BROADCAST_ALL_CHAINS
                && env.destinationChainId != uint32(block.chainid)
        ) {
            revert MessageNotForChain(messageId, env.destinationChainId, uint32(block.chainid));
        }
        if (env.version != VERSION) {
            revert MessageWrongVersion(messageId, env.version, VERSION);
        }

        VerifierType verifierType = getVerifierType(_message);
        _verify(verifierType, env.destinationAddress, _proofData, _message);

        executed[messageId] = true;
        bytes memory receiveCall = abi.encodeWithSelector(
            ITelepathyHandlerV2.handleTelepathy.selector,
            env.sourceChainId,
            env.sourceAddress,
            env.data
        );
        (bool success, bytes memory data) = env.destinationAddress.call(receiveCall);
        if (!success) {
            revert CallFailed();
        }
        bool implementsHandler = false;
        if (data.length == 32) {
            bytes4 magic = abi.decode(data, (bytes4));
            implementsHandler = magic == ITelepathyHandlerV2.handleTelepathy.selector;
        }
        if (!implementsHandler) {
            revert InvalidSelector();
        }
    }

    function _verify(
        VerifierType _verifierType,
        address _destination,
        bytes memory _proofData,
        bytes memory _message
    ) internal {
        if (_verifierType == VerifierType.ZK_EVENT || _verifierType == VerifierType.ZK_STORAGE) {
            if (!zkRelayers[msg.sender]) {
                revert NotZkRelayer(msg.sender);
            }
        }

        address verifier =
            _verifierType == VerifierType.CUSTOM ? _destination : defaultVerifiers[_verifierType];
        if (verifier == address(0)) {
            revert VerifierNotFound(uint256(_verifierType));
        }

        try IMessageVerifier(verifier).verify(_proofData, _message) returns (bool isValid) {
            if (!isValid) {
                revert VerificationFailed();
            }
        } catch {
            revert VerificationFailed();
        }
    }
}

contract AlwaysTrueVerifier is IMessageVerifier {
    function verify(bytes calldata, bytes calldata) external pure returns (bool) {
        return true;
    }
}

contract AlwaysFalseVerifier is IMessageVerifier {
    function verify(bytes calldata, bytes calldata) external pure returns (bool) {
        return false;
    }
}

contract MinimalHandler is ITelepathyHandlerV2, IVerifierTypeHint {
    uint256 public calls;
    uint32 public lastSourceChain;
    address public lastSourceAddress;
    bytes32 public lastPayloadHash;
    address public immutable expectedRouter;
    VerifierType public mode;

    constructor(address _expectedRouter, VerifierType _mode) {
        expectedRouter = _expectedRouter;
        mode = _mode;
    }

    function setVerifierType(VerifierType _mode) external {
        mode = _mode;
    }

    function verifierType() external view returns (VerifierType) {
        return mode;
    }

    function handleTelepathy(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
        external
        returns (bytes4)
    {
        require(msg.sender == expectedRouter, "router only");
        calls += 1;
        lastSourceChain = _sourceChainId;
        lastSourceAddress = _sourceAddress;
        lastPayloadHash = keccak256(_data);
        return ITelepathyHandlerV2.handleTelepathy.selector;
    }
}
