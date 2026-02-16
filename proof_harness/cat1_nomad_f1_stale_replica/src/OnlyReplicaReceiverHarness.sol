// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IXAppConnectionManagerLike {
    function isReplica(address _replica) external view returns (bool);
}

/// @notice Minimal receiver that enforces the same onlyReplica-style gate.
contract OnlyReplicaReceiverHarness {
    IXAppConnectionManagerLike public xcm;
    uint256 public handled;

    constructor(address _xcm) {
        xcm = IXAppConnectionManagerLike(_xcm);
    }

    function handle() external {
        require(xcm.isReplica(msg.sender), "!replica");
        handled += 1;
    }
}

/// @notice Simulates calls coming from a replica contract address.
contract ReplicaCallerHarness {
    function callHandle(address receiver) external returns (bool, bytes memory) {
        return receiver.call(abi.encodeWithSignature("handle()"));
    }
}

