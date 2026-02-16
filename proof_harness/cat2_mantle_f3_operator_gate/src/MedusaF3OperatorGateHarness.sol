// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChallengeSettlementHarness, DefenderCaller, RollupOperatorGateHarness} from "./MantleF3Harness.sol";

/// @notice Stateful fuzz harness for Mantle F-MAN-03.
/// @dev Intended property: once settlement is attempted after setup, it should succeed.
///      Medusa is expected to falsify this property unless the challenge address is
///      explicitly operator-registered.
contract MedusaF3OperatorGateHarness {
    RollupOperatorGateHarness public rollup;
    DefenderCaller public defenderBot;
    ChallengeSettlementHarness public challenge;

    address public defenderOperator;
    address public challengerOperator;
    address public defenderStaker;
    address public challengerStaker;
    address public syntheticChallengeOperatorStaker;

    bool public initialized;
    bool public syntheticRegistrationDone;
    bool public attemptedSettlement;
    bool public settlementSucceeded;

    constructor() {
        rollup = new RollupOperatorGateHarness();
        defenderBot = new DefenderCaller();

        defenderOperator = address(defenderBot);
        challengerOperator = address(0xC0FFEE);
        defenderStaker = address(0xAA01);
        challengerStaker = address(0xBB02);
        syntheticChallengeOperatorStaker = address(0xCC03);
    }

    function action_setup() public {
        if (initialized) {
            return;
        }

        rollup.register(defenderOperator, defenderStaker);
        rollup.register(challengerOperator, challengerStaker);

        challenge = new ChallengeSettlementHarness(defenderOperator, challengerOperator, address(rollup));
        rollup.pairChallenge(defenderOperator, challengerOperator, address(challenge));
        challenge.setWinner(defenderOperator);
        initialized = true;
    }

    function action_register_challenge_as_operator() public {
        if (!initialized || syntheticRegistrationDone) {
            return;
        }
        rollup.register(address(challenge), syntheticChallengeOperatorStaker);
        syntheticRegistrationDone = true;
    }

    function action_attempt_settlement(bool result) public {
        if (!initialized) {
            return;
        }

        attemptedSettlement = true;
        try defenderBot.callComplete(challenge, result) {
            settlementSucceeded = true;
        } catch {
            settlementSucceeded = false;
        }
    }

    /// @notice Security property we expect in robust settlement logic:
    ///         an attempted settlement should not require hidden registration side effects.
    function property_settlement_progresses_without_hidden_registration() public view returns (bool) {
        if (!attemptedSettlement) {
            return true;
        }
        return settlementSucceeded;
    }
}
