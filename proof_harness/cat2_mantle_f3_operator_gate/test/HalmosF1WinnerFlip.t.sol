// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChallengeSettlementHarness, DefenderCaller} from "../src/MantleF3Harness.sol";

interface IRecorderCallback {
    function completeChallenge(address winner, address loser) external;
}

contract RecorderCallback is IRecorderCallback {
    address public lastWinner;
    address public lastLoser;

    function completeChallenge(address winner, address loser) external {
        lastWinner = winner;
        lastLoser = loser;
    }
}

/// @notice Halmos symbolic check for Mantle F-MAN-01.
/// @dev Expected secure property:
///      a challenger win cannot be rewritten by defender-controlled boolean.
contract HalmosF1WinnerFlip {
    function check_challenger_win_cannot_be_rewritten(bool defenderResult) public {
        DefenderCaller defenderBot = new DefenderCaller();
        address defender = address(defenderBot);
        address challenger = address(0xC0FFEE);

        RecorderCallback recorder = new RecorderCallback();
        ChallengeSettlementHarness challenge = new ChallengeSettlementHarness(defender, challenger, address(recorder));
        challenge.setWinner(challenger);

        defenderBot.callComplete(challenge, defenderResult);

        assert(challenge.winner() == challenger);
    }
}
