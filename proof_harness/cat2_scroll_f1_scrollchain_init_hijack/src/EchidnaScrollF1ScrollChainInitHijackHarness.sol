// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ScrollF1SimpleProxy,
    ScrollChainLike,
    ScrollChainInitAttacker,
    IScrollChainLike
} from "./ScrollF1ScrollChainInitHijackHarness.sol";

/// @notice Echidna harness for ScrollChain initializer takeover.
contract EchidnaScrollF1ScrollChainInitHijackHarness {
    ScrollF1SimpleProxy public proxy;
    IScrollChainLike public rollup;
    ScrollChainInitAttacker public attacker;

    address public attackerOwner;

    constructor() {
        ScrollChainLike implementation = new ScrollChainLike();
        proxy = new ScrollF1SimpleProxy(address(this));
        proxy.upgradeTo(address(implementation));
        rollup = IScrollChainLike(address(proxy));
        attacker = new ScrollChainInitAttacker();
        attackerOwner = address(attacker);
    }

    function action_attacker_initialize() public {
        try attacker.hijack(address(proxy), address(0x1111), address(0x2222), 100) {} catch {}
    }

    function echidna_non_admin_cannot_take_scrollchain_owner() public view returns (bool) {
        return rollup.owner() != attackerOwner;
    }
}
