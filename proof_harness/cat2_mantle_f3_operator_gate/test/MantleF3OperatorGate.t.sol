// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChallengeSettlementHarness, DefenderCaller, RollupOperatorGateHarness} from "../src/MantleF3Harness.sol";

contract MantleF3OperatorGateTest {
    function test_reverts_when_challenge_contract_is_not_registered_operator() public {
        RollupOperatorGateHarness rollup = new RollupOperatorGateHarness();
        DefenderCaller defenderBot = new DefenderCaller();

        address defenderOperator = address(defenderBot);
        address challengerOperator = address(0xC0FFEE);
        address defenderStaker = address(0xAA01);
        address challengerStaker = address(0xBB02);

        rollup.register(defenderOperator, defenderStaker);
        rollup.register(challengerOperator, challengerStaker);

        ChallengeSettlementHarness challenge =
            new ChallengeSettlementHarness(defenderOperator, challengerOperator, address(rollup));
        rollup.pairChallenge(defenderOperator, challengerOperator, address(challenge));
        challenge.setWinner(defenderOperator);

        try defenderBot.callComplete(challenge, false) {
            revert("expected call to revert");
        } catch Error(string memory reason) {
            require(_eq(reason, "NotOperator"), "unexpected revert reason");
        }

        require(!rollup.challengeCompleted(), "challenge should remain uncompleted");
    }

    function test_succeeds_only_after_registering_challenge_contract_as_operator() public {
        RollupOperatorGateHarness rollup = new RollupOperatorGateHarness();
        DefenderCaller defenderBot = new DefenderCaller();

        address defenderOperator = address(defenderBot);
        address challengerOperator = address(0xD0D0);
        address defenderStaker = address(0xCC03);
        address challengerStaker = address(0xDD04);
        address syntheticChallengeOperatorStaker = address(0xEE05);

        rollup.register(defenderOperator, defenderStaker);
        rollup.register(challengerOperator, challengerStaker);

        ChallengeSettlementHarness challenge =
            new ChallengeSettlementHarness(defenderOperator, challengerOperator, address(rollup));
        rollup.pairChallenge(defenderOperator, challengerOperator, address(challenge));
        challenge.setWinner(defenderOperator);

        // Hidden requirement: challenge address must be inserted in operator registry.
        rollup.register(address(challenge), syntheticChallengeOperatorStaker);

        defenderBot.callComplete(challenge, false);
        require(rollup.challengeCompleted(), "challenge should complete after synthetic registration");
    }

    function _eq(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
