// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChallengeBindingRollupHarness, ChallengeBindingStub} from "../src/MantleF4ChallengeBindingHarness.sol";

contract MantleF4ChallengeBindingTest {
    function test_unbound_victim_can_be_forced_into_challenge_with_unrelated_assertion_ids() public {
        ChallengeBindingRollupHarness rollup = new ChallengeBindingRollupHarness();

        // Seed sibling assertions 10/11 under parent 1.
        rollup.seedAssertion(10, 1);
        rollup.seedAssertion(11, 1);
        rollup.setLastConfirmedAssertionID(0);

        address attackerOperator = address(this);
        address victimOperator = address(0xBEEF);
        address attackerStaker = address(0xA001);
        address victimStaker = address(0xA002);

        // Both operators are valid stakers, but on unrelated assertion IDs 42/43.
        rollup.seedStaker(attackerOperator, attackerStaker, 42, 2 ether);
        rollup.seedStaker(victimOperator, victimStaker, 43, 1 ether);

        address[2] memory players = [victimOperator, attackerOperator];
        uint256[2] memory assertionIDs = [uint256(10), uint256(11)];

        // Challenge is accepted despite players not staked on 10/11.
        address challengeAddr = rollup.challengeAssertion(players, assertionIDs);
        require(challengeAddr != address(0), "challenge creation failed");

        // Victim is now force-placed into an active challenge despite unrelated assertion position.
        (,,, , address victimCurrentChallenge) = rollup.stakers(victimStaker);
        require(victimCurrentChallenge == challengeAddr, "victim should be in forced challenge");
    }

    function test_unbound_victim_can_be_slashed_when_challenge_address_is_registered() public {
        ChallengeBindingRollupHarness rollup = new ChallengeBindingRollupHarness();

        rollup.seedAssertion(10, 1);
        rollup.seedAssertion(11, 1);
        rollup.setLastConfirmedAssertionID(0);

        address attackerOperator = address(this);
        address victimOperator = address(0xBEEF);
        address attackerStaker = address(0xA001);
        address victimStaker = address(0xA002);
        address syntheticChallengeStaker = address(0xA003);

        rollup.seedStaker(attackerOperator, attackerStaker, 42, 2 ether);
        rollup.seedStaker(victimOperator, victimStaker, 43, 1 ether);

        address[2] memory players = [victimOperator, attackerOperator];
        uint256[2] memory assertionIDs = [uint256(10), uint256(11)];
        address challengeAddr = rollup.challengeAssertion(players, assertionIDs);

        // F-MAN-03 workaround: register challenge address as operator so settlement can execute.
        rollup.seedStaker(challengeAddr, syntheticChallengeStaker, 99, 1 ether);
        ChallengeBindingStub(challengeAddr).settle(attackerOperator, victimOperator);

        (bool victimStaked,,,,) = rollup.stakers(victimStaker);
        require(!victimStaked, "victim should be slashed");
    }
}
