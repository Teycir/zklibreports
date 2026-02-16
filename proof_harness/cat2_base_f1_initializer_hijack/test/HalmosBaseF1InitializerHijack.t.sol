// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    BaseF1SimpleProxy,
    BaseF1BalanceTrackerLike,
    BaseF1InitializerAttacker,
    IBalanceTrackerLike
} from "../src/BaseF1InitializerHijackHarness.sol";

/// @notice Halmos check for unauthorized initializer takeover.
contract HalmosBaseF1InitializerHijack {
    function check_non_admin_cannot_hijack_initialize() public {
        address admin = address(this);
        address payable profitWallet = payable(address(0xF00D));
        address payable attackerRecipient = payable(address(0xBEEF));

        BaseF1BalanceTrackerLike implementation = new BaseF1BalanceTrackerLike(profitWallet);
        BaseF1SimpleProxy proxy = new BaseF1SimpleProxy(admin);
        IBalanceTrackerLike tracker = IBalanceTrackerLike(address(proxy));
        BaseF1InitializerAttacker attacker = new BaseF1InitializerAttacker();

        proxy.upgradeTo(address(implementation));

        attacker.hijack(address(proxy), attackerRecipient, type(uint256).max);

        uint256 len = tracker.systemAddressesLength();
        if (len > 0) {
            assert(tracker.systemAddresses(0) != attackerRecipient);
        }
    }
}
