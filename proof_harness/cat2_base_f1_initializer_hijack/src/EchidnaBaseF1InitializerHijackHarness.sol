// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    BaseF1SimpleProxy,
    BaseF1BalanceTrackerLike,
    BaseF1InitializerAttacker,
    IBalanceTrackerLike
} from "./BaseF1InitializerHijackHarness.sol";

/// @notice Echidna harness for unauthorized BalanceTracker initializer takeover.
contract EchidnaBaseF1InitializerHijackHarness {
    BaseF1SimpleProxy public proxy;
    IBalanceTrackerLike public tracker;
    BaseF1InitializerAttacker public attacker;

    address payable public attackerRecipient;

    constructor() {
        address payable profitWallet = payable(address(0xF00D));
        attackerRecipient = payable(address(0xBEEF));

        BaseF1BalanceTrackerLike implementation = new BaseF1BalanceTrackerLike(profitWallet);
        proxy = new BaseF1SimpleProxy(address(this));
        proxy.upgradeTo(address(implementation));
        tracker = IBalanceTrackerLike(address(proxy));

        attacker = new BaseF1InitializerAttacker();
    }

    function action_attacker_initialize() public {
        // Subsequent calls revert due to reinitializer guard.
        // Keep call wrapped to allow Echidna to continue exploring.
        try attacker.hijack(address(proxy), attackerRecipient, type(uint256).max) {} catch {}
    }

    function echidna_non_admin_cannot_take_first_system_address() public view returns (bool) {
        uint256 len = tracker.systemAddressesLength();
        if (len == 0) {
            return true;
        }
        return tracker.systemAddresses(0) != attackerRecipient;
    }
}
