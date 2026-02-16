// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    BridgeReplayBugModel,
    BridgeReplayGuardModel,
    MockReentrantToken
} from "../src/ReentrancyReplayHarness.sol";

contract ReentrancyReplayTest {
    uint256 internal constant INITIAL_MINT = 1_000_000 ether;

    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    /// @notice Control witness: vulnerable ordering allows same-VM double redemption via reentrancy.
    function test_bug_model_allows_same_vm_double_redeem_via_reentrancy() public {
        BridgeReplayBugModel bug = new BridgeReplayBugModel();
        MockReentrantToken token = new MockReentrantToken(address(bug));

        token.mint(address(this), INITIAL_MINT);
        token.approve(address(bug), type(uint256).max);
        bug.seed(address(token), address(this), 200 ether);

        bytes32 vmHash = keccak256("bug-vm");
        bug.registerTransfer(vmHash, address(token), address(this), 100 ether);
        token.configureHook(vmHash, true);

        bug.completeTransfer(vmHash);

        _assertTrue(
            bug.redeemCount(vmHash) == 2,
            "expected double redeem in vulnerable ordering"
        );
        _assertTrue(
            bug.outstanding(address(token)) == 0,
            "expected double accounting debit"
        );
    }

    /// @notice Target witness: Wormhole-like ordering prevents same-VM double redemption.
    function test_guard_model_blocks_same_vm_double_redeem_via_reentrancy() public {
        BridgeReplayGuardModel guard = new BridgeReplayGuardModel();
        MockReentrantToken token = new MockReentrantToken(address(guard));

        token.mint(address(this), INITIAL_MINT);
        token.approve(address(guard), type(uint256).max);
        guard.seed(address(token), address(this), 200 ether);

        bytes32 vmHash = keccak256("guard-vm");
        guard.registerTransfer(vmHash, address(token), address(this), 100 ether);
        token.configureHook(vmHash, true);

        guard.completeTransfer(vmHash);

        _assertTrue(
            guard.redeemCount(vmHash) == 1,
            "expected single redeem in guarded ordering"
        );
        _assertTrue(
            guard.outstanding(address(token)) == 100 ether,
            "expected single accounting debit"
        );
    }

    /// @notice Fuzz: same-VM reentrancy never pushes guard model above one redeem.
    function testFuzz_guard_model_never_double_redeems_same_vm(uint96 amountSeed)
        public
    {
        BridgeReplayGuardModel guard = new BridgeReplayGuardModel();
        MockReentrantToken token = new MockReentrantToken(address(guard));

        token.mint(address(this), INITIAL_MINT);
        token.approve(address(guard), type(uint256).max);

        uint256 amount = (uint256(amountSeed) % 1_000 ether) + 1;
        guard.seed(address(token), address(this), amount * 2);

        bytes32 vmHash = keccak256(abi.encodePacked("guard-fuzz", amountSeed));
        guard.registerTransfer(vmHash, address(token), address(this), amount);
        token.configureHook(vmHash, true);

        guard.completeTransfer(vmHash);

        _assertTrue(guard.redeemCount(vmHash) == 1, "unexpected double redeem");
    }
}

