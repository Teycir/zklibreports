// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChallengeSettlementHarness, DefenderCaller, RollupOperatorGateHarness} from "../src/MantleF3Harness.sol";

/// @notice Halmos symbolic check for Mantle F-MAN-03.
/// @dev Expected secure property:
///      after challenge setup, settlement should progress without hidden
///      operator registration of the challenge address itself.
contract HalmosF3OperatorGate {
    function check_settlement_progresses_without_hidden_registration(bool defenderResult) public {
        RollupOperatorGateHarness rollup = new RollupOperatorGateHarness();
        DefenderCaller defenderBot = new DefenderCaller();

        address defenderOperator = address(defenderBot);
        address challengerOperator = address(0xBEEF);
        address defenderStaker = address(0xAA01);
        address challengerStaker = address(0xBB02);

        rollup.register(defenderOperator, defenderStaker);
        rollup.register(challengerOperator, challengerStaker);

        ChallengeSettlementHarness challenge =
            new ChallengeSettlementHarness(defenderOperator, challengerOperator, address(rollup));
        rollup.pairChallenge(defenderOperator, challengerOperator, address(challenge));
        challenge.setWinner(defenderOperator);

        try defenderBot.callComplete(challenge, defenderResult) {} catch {}

        assert(rollup.challengeCompleted());
    }
}
