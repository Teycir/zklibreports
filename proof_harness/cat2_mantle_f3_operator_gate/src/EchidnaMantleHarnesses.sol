// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChallengeSettlementHarness, DefenderCaller, RollupOperatorGateHarness} from "./MantleF3Harness.sol";

interface IRollupCompleteCallback {
    function completeChallenge(address winner, address loser) external;
}

contract RollupCallbackRecorder is IRollupCompleteCallback {
    address public lastWinner;
    address public lastLoser;
    uint256 public callCount;

    function completeChallenge(address winner, address loser) external {
        lastWinner = winner;
        lastLoser = loser;
        callCount++;
    }
}

/// @notice Echidna witness harness for F-MAN-01.
/// @dev Property expected by secure settlement:
///      once challenger is winner, defender cannot rewrite outcome.
contract EchidnaF1WinnerFlipHarness {
    DefenderCaller public defenderBot;
    ChallengeSettlementHarness public challenge;
    RollupCallbackRecorder public recorder;

    address public defenderOperator;
    address public challengerOperator;

    constructor() {
        defenderBot = new DefenderCaller();
        recorder = new RollupCallbackRecorder();

        defenderOperator = address(defenderBot);
        challengerOperator = address(0xC0FFEE);

        challenge = new ChallengeSettlementHarness(defenderOperator, challengerOperator, address(recorder));
        challenge.setWinner(challengerOperator);
    }

    function action_defender_settles_false() public {
        defenderBot.callComplete(challenge, false);
    }

    function action_defender_settles_true() public {
        defenderBot.callComplete(challenge, true);
    }

    function echidna_challenger_win_cannot_be_rewritten() public view returns (bool) {
        return challenge.winner() == challengerOperator;
    }
}

/// @notice Echidna witness harness for F-MAN-03.
/// @dev Property expected by robust challenge plumbing:
///      after setup, settlement should progress without hidden operator registration.
contract EchidnaF3OperatorGateHarness {
    RollupOperatorGateHarness public rollup;
    DefenderCaller public defenderBot;
    ChallengeSettlementHarness public challenge;

    address public defenderOperator;
    address public challengerOperator;
    address public defenderStaker;
    address public challengerStaker;
    address public syntheticChallengeOperatorStaker;

    bool public attemptedSettlement;
    bool public registeredChallengeOperator;

    constructor() {
        rollup = new RollupOperatorGateHarness();
        defenderBot = new DefenderCaller();

        defenderOperator = address(defenderBot);
        challengerOperator = address(0xBEEF);
        defenderStaker = address(0xAA01);
        challengerStaker = address(0xBB02);
        syntheticChallengeOperatorStaker = address(0xCC03);

        rollup.register(defenderOperator, defenderStaker);
        rollup.register(challengerOperator, challengerStaker);

        challenge = new ChallengeSettlementHarness(defenderOperator, challengerOperator, address(rollup));
        rollup.pairChallenge(defenderOperator, challengerOperator, address(challenge));
        challenge.setWinner(defenderOperator);
    }

    function action_attempt_settlement(bool result) public {
        attemptedSettlement = true;
        try defenderBot.callComplete(challenge, result) {} catch {}
    }

    function action_register_challenge_operator() public {
        if (registeredChallengeOperator) {
            return;
        }
        rollup.register(address(challenge), syntheticChallengeOperatorStaker);
        registeredChallengeOperator = true;
    }

    function echidna_settlement_progresses_without_hidden_registration() public view returns (bool) {
        if (!attemptedSettlement) {
            return true;
        }
        return rollup.challengeCompleted();
    }
}
