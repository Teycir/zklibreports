// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {XAppConnectionManagerBug} from "./XAppConnectionManagerHarness.sol";

/// @notice Stateful harness for Medusa.
/// Action functions mutate buggy XCM state.
/// `property_*` functions encode authorization/mapping invariants.
contract MedusaXcmF1Harness {
    XAppConnectionManagerBug public xcm;

    uint8 internal constant MAX_REPLICAS = 8;
    uint8 internal constant MAX_DOMAINS = 8;

    constructor() {
        xcm = new XAppConnectionManagerBug();
    }

    function _replica(uint8 id) internal pure returns (address) {
        // Deterministic non-zero pseudo-addresses in a small bounded set.
        return address(uint160(uint256(keccak256(abi.encodePacked("replica", id))) | 1));
    }

    function _domain(uint32 raw) internal pure returns (uint32) {
        // Keep domains in [1..MAX_DOMAINS] to avoid zero sentinel.
        return uint32((raw % MAX_DOMAINS) + 1);
    }

    // -------- Actions Medusa can sequence --------

    function action_enroll(uint8 replicaId, uint32 domainRaw) external {
        address replica = _replica(replicaId % MAX_REPLICAS);
        uint32 domain = _domain(domainRaw);
        xcm.ownerEnrollReplica(replica, domain);
    }

    function action_unenroll(uint8 replicaId) external {
        address replica = _replica(replicaId % MAX_REPLICAS);
        xcm.ownerUnenrollReplica(replica);
    }

    // -------- Invariants Medusa should preserve (but bug violates) --------

    /// @notice Invariant: no two authorized replicas should map to the same domain.
    function property_unique_replica_per_domain() external view returns (bool) {
        for (uint8 i = 0; i < MAX_REPLICAS; i++) {
            address ri = _replica(i);
            if (!xcm.isReplica(ri)) continue;
            uint32 di = xcm.replicaToDomain(ri);

            for (uint8 j = i + 1; j < MAX_REPLICAS; j++) {
                address rj = _replica(j);
                if (!xcm.isReplica(rj)) continue;
                if (xcm.replicaToDomain(rj) == di) return false;
            }
        }
        return true;
    }

    /// @notice Invariant: forward/reverse mapping should be consistent for authorized replicas.
    function property_bidirectional_mapping_consistency()
        external
        view
        returns (bool)
    {
        for (uint8 i = 0; i < MAX_REPLICAS; i++) {
            address ri = _replica(i);
            if (!xcm.isReplica(ri)) continue;
            uint32 di = xcm.replicaToDomain(ri);
            if (xcm.domainToReplica(di) != ri) return false;
        }
        return true;
    }
}

