// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    OptimismF1SimpleProxy,
    ProtocolVersionsLike,
    ProtocolVersionsInitAttacker,
    IProtocolVersionsLike
} from "../src/OptimismF1ProtocolVersionsInitHijackHarness.sol";

/// @notice Halmos check for ProtocolVersions initializer takeover.
contract HalmosOptimismF1ProtocolVersionsInitHijack {
    function check_non_admin_cannot_take_protocol_owner() public {
        address admin = address(this);
        address attackerOwner = address(0xBEEF);

        ProtocolVersionsLike implementation = new ProtocolVersionsLike();
        OptimismF1SimpleProxy proxy = new OptimismF1SimpleProxy(admin);
        IProtocolVersionsLike protocolVersions = IProtocolVersionsLike(address(proxy));
        ProtocolVersionsInitAttacker attacker = new ProtocolVersionsInitAttacker();

        proxy.upgradeTo(address(implementation));
        attacker.hijack(address(proxy), attackerOwner, 111, 222);

        assert(protocolVersions.owner() != attackerOwner);
    }
}
