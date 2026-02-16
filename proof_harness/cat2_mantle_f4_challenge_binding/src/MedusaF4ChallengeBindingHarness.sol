// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChallengeBindingRollupHarness, ChallengeBindingStub} from "./MantleF4ChallengeBindingHarness.sol";

/// @notice Stateful Medusa harness for F-MAN-04.
contract MedusaF4ChallengeBindingHarness {
    ChallengeBindingRollupHarness public rollup;

    address public attackerOperator;
    address public victimOperator;
    address public attackerStaker;
    address public victimStaker;
    address public syntheticChallengeStaker;
    address public challengeAddr;

    bool public opened;
    bool public settled;

    constructor() {
        rollup = new ChallengeBindingRollupHarness();
        rollup.seedAssertion(10, 1);
        rollup.seedAssertion(11, 1);
        rollup.setLastConfirmedAssertionID(0);

        attackerOperator = address(this);
        victimOperator = address(0xBEEF);
        attackerStaker = address(0xA001);
        victimStaker = address(0xA002);
        syntheticChallengeStaker = address(0xA003);

        rollup.seedStaker(attackerOperator, attackerStaker, 42, 2 ether);
        rollup.seedStaker(victimOperator, victimStaker, 43, 1 ether);
    }

    function action_open_mismatched_challenge() public {
        if (opened) {
            return;
        }
        address[2] memory players = [victimOperator, attackerOperator];
        uint256[2] memory assertionIDs = [uint256(10), uint256(11)];
        challengeAddr = rollup.challengeAssertion(players, assertionIDs);
        opened = true;
    }

    function action_register_challenge_as_operator() public {
        if (!opened) {
            return;
        }
        rollup.seedStaker(challengeAddr, syntheticChallengeStaker, 99, 1 ether);
    }

    function action_settle() public {
        if (!opened || settled) {
            return;
        }
        try ChallengeBindingStub(challengeAddr).settle(attackerOperator, victimOperator) {
            settled = true;
        } catch {}
    }

    /// @notice Property that should hold if players/assertion IDs are correctly bound.
    function property_victim_not_forced_into_unrelated_challenge() public view returns (bool) {
        (,,, , address victimCurrentChallenge) = rollup.stakers(victimStaker);
        return victimCurrentChallenge == address(0);
    }

    /// @notice Property that should hold if unbound slashing is impossible.
    function property_victim_not_slashed_by_unrelated_assertions() public view returns (bool) {
        (bool victimStaked,,,,) = rollup.stakers(victimStaker);
        return victimStaked;
    }
}
