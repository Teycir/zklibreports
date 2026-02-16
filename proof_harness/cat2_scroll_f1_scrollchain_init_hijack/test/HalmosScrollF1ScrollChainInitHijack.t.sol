// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ScrollF1SimpleProxy,
    ScrollChainLike,
    ScrollChainInitAttacker,
    IScrollChainLike
} from "../src/ScrollF1ScrollChainInitHijackHarness.sol";

/// @notice Halmos check for ScrollChain initializer takeover.
contract HalmosScrollF1ScrollChainInitHijack {
    function check_non_admin_cannot_take_scrollchain_owner() public {
        address admin = address(this);

        ScrollChainLike implementation = new ScrollChainLike();
        ScrollF1SimpleProxy proxy = new ScrollF1SimpleProxy(admin);
        IScrollChainLike rollup = IScrollChainLike(address(proxy));
        ScrollChainInitAttacker attacker = new ScrollChainInitAttacker();
        address attackerOwner = address(attacker);

        proxy.upgradeTo(address(implementation));
        attacker.hijack(address(proxy), address(0x1111), address(0x2222), 100);

        assert(rollup.owner() != attackerOwner);
    }
}
