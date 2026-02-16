// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library MerkleBranchLite {
    function branchRoot(
        bytes32 _leaf,
        bytes32[32] memory _proof,
        uint256 _index
    ) internal pure returns (bytes32 _root) {
        _root = _leaf;
        for (uint256 i = 0; i < 32; i++) {
            bytes32 _sibling = _proof[i];
            if ((_index & 1) == 1) {
                _root = keccak256(abi.encodePacked(_sibling, _root));
            } else {
                _root = keccak256(abi.encodePacked(_root, _sibling));
            }
            _index >>= 1;
        }
    }
}

/// @notice Model of Replica root-acceptance behavior as implemented:
/// bootstrap root is marked acceptable immediately with `confirmAt[root] = 1`.
contract ReplicaBootstrapBug {
    enum MessageStatus {
        None,
        Proven,
        Processed
    }

    uint256 public optimisticSeconds;
    bytes32 public committedRoot;
    mapping(bytes32 => uint256) public confirmAt;
    mapping(bytes32 => MessageStatus) public messages;

    constructor(bytes32 _committedRoot, uint256 _optimisticSeconds) {
        committedRoot = _committedRoot;
        optimisticSeconds = _optimisticSeconds;
        confirmAt[_committedRoot] = 1;
    }

    function acceptableRoot(bytes32 _root) public view returns (bool) {
        uint256 _time = confirmAt[_root];
        if (_time == 0) return false;
        return block.timestamp >= _time;
    }

    function prove(
        bytes32 _leaf,
        bytes32[32] calldata _proof,
        uint256 _index
    ) external returns (bool) {
        require(messages[_leaf] == MessageStatus.None, "!MessageStatus.None");
        bytes32 _calculated = MerkleBranchLite.branchRoot(_leaf, _proof, _index);
        if (acceptableRoot(_calculated)) {
            messages[_leaf] = MessageStatus.Proven;
            return true;
        }
        return false;
    }
}

/// @notice Reference fix model:
/// bootstrap root respects optimistic timeout instead of instant acceptance.
contract ReplicaBootstrapFixed {
    enum MessageStatus {
        None,
        Proven,
        Processed
    }

    uint256 public optimisticSeconds;
    bytes32 public committedRoot;
    mapping(bytes32 => uint256) public confirmAt;
    mapping(bytes32 => MessageStatus) public messages;

    constructor(bytes32 _committedRoot, uint256 _optimisticSeconds) {
        committedRoot = _committedRoot;
        optimisticSeconds = _optimisticSeconds;
        confirmAt[_committedRoot] = block.timestamp + _optimisticSeconds;
    }

    function acceptableRoot(bytes32 _root) public view returns (bool) {
        uint256 _time = confirmAt[_root];
        if (_time == 0) return false;
        return block.timestamp >= _time;
    }

    function prove(
        bytes32 _leaf,
        bytes32[32] calldata _proof,
        uint256 _index
    ) external returns (bool) {
        require(messages[_leaf] == MessageStatus.None, "!MessageStatus.None");
        bytes32 _calculated = MerkleBranchLite.branchRoot(_leaf, _proof, _index);
        if (acceptableRoot(_calculated)) {
            messages[_leaf] = MessageStatus.Proven;
            return true;
        }
        return false;
    }
}

