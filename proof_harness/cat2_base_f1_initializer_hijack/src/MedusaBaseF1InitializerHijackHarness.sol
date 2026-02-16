// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    BaseF1SimpleProxy,
    BaseF1BalanceTrackerLike,
    BaseF1InitializerAttacker,
    IBalanceTrackerLike
} from "./BaseF1InitializerHijackHarness.sol";

/// @notice Stateful Medusa harness for unauthorized BalanceTracker initializer takeover.
contract MedusaBaseF1InitializerHijackHarness {
    BaseF1SimpleProxy public proxy;
    IBalanceTrackerLike public tracker;
    BaseF1InitializerAttacker public attacker;

    address payable public profitWallet;
    address payable public attackerRecipient;

    bool public attacked;

    constructor() {
        profitWallet = payable(address(0xF00D));
        attackerRecipient = payable(address(0xBEEF));

        BaseF1BalanceTrackerLike implementation = new BaseF1BalanceTrackerLike(profitWallet);
        proxy = new BaseF1SimpleProxy(address(this));
        proxy.upgradeTo(address(implementation));
        tracker = IBalanceTrackerLike(address(proxy));

        attacker = new BaseF1InitializerAttacker();
    }

    function action_attacker_initialize() public {
        if (attacked) {
            return;
        }
        attacker.hijack(address(proxy), attackerRecipient, type(uint256).max);
        attacked = true;
    }

    /// @notice Property that should hold in a safe design: a non-admin attacker should not become system recipient.
    function property_non_admin_cannot_take_first_system_address() public view returns (bool) {
        uint256 len = tracker.systemAddressesLength();
        if (len == 0) {
            return true;
        }
        return tracker.systemAddresses(0) != attackerRecipient;
    }
}
