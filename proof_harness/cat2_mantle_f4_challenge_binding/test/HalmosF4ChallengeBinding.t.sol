// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChallengeBindingRollupHarness} from "../src/MantleF4ChallengeBindingHarness.sol";

/// @notice Halmos check for F-MAN-04.
contract HalmosF4ChallengeBinding {
    function check_victim_cannot_be_forced_into_unrelated_challenge() public {
        ChallengeBindingRollupHarness rollup = new ChallengeBindingRollupHarness();
        rollup.seedAssertion(10, 1);
        rollup.seedAssertion(11, 1);
        rollup.setLastConfirmedAssertionID(0);

        address attackerOperator = address(this);
        address victimOperator = address(0xBEEF);
        address attackerStaker = address(0xA001);
        address victimStaker = address(0xA002);

        rollup.seedStaker(attackerOperator, attackerStaker, 42, 2 ether);
        rollup.seedStaker(victimOperator, victimStaker, 43, 1 ether);

        address[2] memory players = [victimOperator, attackerOperator];
        uint256[2] memory assertionIDs = [uint256(10), uint256(11)];
        rollup.challengeAssertion(players, assertionIDs);

        (,,, , address victimCurrentChallenge) = rollup.stakers(victimStaker);
        assert(victimCurrentChallenge == address(0));
    }
}
