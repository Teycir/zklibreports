// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    OptimismF1SimpleProxy,
    ProtocolVersionsLike,
    ProtocolVersionsInitAttacker,
    IProtocolVersionsLike
} from "./OptimismF1ProtocolVersionsInitHijackHarness.sol";

/// @notice Stateful Medusa harness for ProtocolVersions initializer takeover.
contract MedusaOptimismF1ProtocolVersionsInitHijackHarness {
    OptimismF1SimpleProxy public proxy;
    IProtocolVersionsLike public protocolVersions;
    ProtocolVersionsInitAttacker public attacker;

    address public attackerOwner;
    bool public attacked;

    constructor() {
        attackerOwner = address(0xBEEF);

        ProtocolVersionsLike implementation = new ProtocolVersionsLike();
        proxy = new OptimismF1SimpleProxy(address(this));
        proxy.upgradeTo(address(implementation));
        protocolVersions = IProtocolVersionsLike(address(proxy));
        attacker = new ProtocolVersionsInitAttacker();
    }

    function action_attacker_initialize() public {
        if (attacked) {
            return;
        }
        attacker.hijack(address(proxy), attackerOwner, 111, 222);
        attacked = true;
    }

    function property_non_admin_cannot_take_protocol_owner() public view returns (bool) {
        return protocolVersions.owner() != attackerOwner;
    }
}
