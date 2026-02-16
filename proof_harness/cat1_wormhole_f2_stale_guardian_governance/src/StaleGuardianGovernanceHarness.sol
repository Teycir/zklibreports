// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct MiniVM {
    uint32 guardianSetIndex;
    uint16 emitterChainId;
    bytes32 emitterAddress;
    bytes32 hash;
}

/// @notice Model of Wormhole VM verification behavior relevant to guardian-set expiry.
contract WormholeVerificationModel {
    uint32 public currentGuardianSetIndex;
    mapping(uint32 => bool) public guardianSetExists;
    mapping(uint32 => uint256) public guardianSetExpiration;

    function setGuardianSet(uint32 _index, uint256 _expiration) external {
        guardianSetExists[_index] = true;
        guardianSetExpiration[_index] = _expiration;
    }

    function setCurrentGuardianSetIndex(uint32 _index) external {
        require(guardianSetExists[_index], "unknown set");
        currentGuardianSetIndex = _index;
    }

    function parseAndVerifyVM(bytes memory _encodedVm)
        external
        view
        returns (MiniVM memory _vm, bool _valid, string memory _reason)
    {
        _vm = abi.decode(_encodedVm, (MiniVM));

        if (!guardianSetExists[_vm.guardianSetIndex]) {
            return (_vm, false, "invalid guardian set");
        }

        if (
            _vm.guardianSetIndex != currentGuardianSetIndex
                && guardianSetExpiration[_vm.guardianSetIndex] < block.timestamp
        ) {
            return (_vm, false, "guardian set has expired");
        }

        return (_vm, true, "");
    }
}

/// @notice Core governance model that enforces "current guardian set only".
contract CoreGovernanceModel {
    WormholeVerificationModel public immutable wormhole;
    uint16 public immutable governanceChainId;
    bytes32 public immutable governanceContract;

    mapping(bytes32 => bool) public governanceActionConsumed;
    bool public upgraded;

    constructor(
        WormholeVerificationModel _wormhole,
        uint16 _governanceChainId,
        bytes32 _governanceContract
    ) {
        wormhole = _wormhole;
        governanceChainId = _governanceChainId;
        governanceContract = _governanceContract;
    }

    function submitContractUpgrade(bytes memory _encodedVm) external {
        (MiniVM memory vm, bool valid, string memory reason) =
            wormhole.parseAndVerifyVM(_encodedVm);

        require(valid, reason);
        require(
            vm.guardianSetIndex == wormhole.currentGuardianSetIndex(),
            "not signed by current guardian set"
        );
        require(vm.emitterChainId == governanceChainId, "wrong governance chain");
        require(vm.emitterAddress == governanceContract, "wrong governance contract");
        require(!governanceActionConsumed[vm.hash], "governance action already consumed");

        governanceActionConsumed[vm.hash] = true;
        upgraded = true;
    }
}

/// @notice Token bridge governance model with the observed stale-set acceptance gap.
contract BridgeGovernanceBugModel {
    WormholeVerificationModel public immutable wormhole;
    uint16 public immutable governanceChainId;
    bytes32 public immutable governanceContract;

    mapping(bytes32 => bool) public governanceActionConsumed;
    bool public upgraded;

    constructor(
        WormholeVerificationModel _wormhole,
        uint16 _governanceChainId,
        bytes32 _governanceContract
    ) {
        wormhole = _wormhole;
        governanceChainId = _governanceChainId;
        governanceContract = _governanceContract;
    }

    function upgrade(bytes memory _encodedVm) external {
        (MiniVM memory vm, bool valid, string memory reason) =
            wormhole.parseAndVerifyVM(_encodedVm);

        require(valid, reason);
        require(vm.emitterChainId == governanceChainId, "wrong governance chain");
        require(vm.emitterAddress == governanceContract, "wrong governance contract");
        require(!governanceActionConsumed[vm.hash], "governance action already consumed");

        governanceActionConsumed[vm.hash] = true;
        upgraded = true;
    }
}

/// @notice Reference fix model: add "current guardian set only" check to bridge governance.
contract BridgeGovernanceFixedModel {
    WormholeVerificationModel public immutable wormhole;
    uint16 public immutable governanceChainId;
    bytes32 public immutable governanceContract;

    mapping(bytes32 => bool) public governanceActionConsumed;
    bool public upgraded;

    constructor(
        WormholeVerificationModel _wormhole,
        uint16 _governanceChainId,
        bytes32 _governanceContract
    ) {
        wormhole = _wormhole;
        governanceChainId = _governanceChainId;
        governanceContract = _governanceContract;
    }

    function upgrade(bytes memory _encodedVm) external {
        (MiniVM memory vm, bool valid, string memory reason) =
            wormhole.parseAndVerifyVM(_encodedVm);

        require(valid, reason);
        require(
            vm.guardianSetIndex == wormhole.currentGuardianSetIndex(),
            "not signed by current guardian set"
        );
        require(vm.emitterChainId == governanceChainId, "wrong governance chain");
        require(vm.emitterAddress == governanceContract, "wrong governance contract");
        require(!governanceActionConsumed[vm.hash], "governance action already consumed");

        governanceActionConsumed[vm.hash] = true;
        upgraded = true;
    }
}

