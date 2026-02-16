// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IRollupCallback {
    function completeChallenge(address winner, address loser) external;
}

/// @notice Minimal model of Mantle Rollup challenge settlement gating:
///         operatorOnly + msg.sender == challenge.
contract RollupOperatorGateHarness {
    struct Staker {
        bool isStaked;
        address currentChallenge;
    }

    mapping(address => Staker) public stakers;
    mapping(address => address) public registers; // operator => staker
    bool public challengeCompleted;

    function register(address operator, address staker) external {
        registers[operator] = staker;
        stakers[staker].isStaked = true;
    }

    function pairChallenge(address winnerOperator, address loserOperator, address challenge) external {
        address winnerStaker = registers[winnerOperator];
        address loserStaker = registers[loserOperator];
        stakers[winnerStaker].currentChallenge = challenge;
        stakers[loserStaker].currentChallenge = challenge;
    }

    modifier operatorOnly() {
        if (registers[msg.sender] == address(0)) {
            revert("NotOperator");
        }
        _;
    }

    function completeChallenge(address winner, address loser) external operatorOnly {
        address winnerStaker = registers[winner];
        address loserStaker = registers[loser];
        if (!stakers[loserStaker].isStaked) {
            revert("NotStaked");
        }

        address challenge = _getChallenge(winnerStaker, loserStaker);
        if (msg.sender != challenge) {
            revert("NotChallenge");
        }

        challengeCompleted = true;
    }

    function _getChallenge(address winnerStaker, address loserStaker) private view returns (address) {
        address challenge = stakers[winnerStaker].currentChallenge;
        if (challenge == address(0)) {
            revert("NotInChallenge");
        }
        if (challenge != stakers[loserStaker].currentChallenge) {
            revert("InDifferentChallenge");
        }
        return challenge;
    }
}

/// @notice Minimal model of Mantle Challenge.completeChallenge(bool result).
contract ChallengeSettlementHarness {
    address public defender;
    address public challenger;
    address public resultReceiver;
    address public winner;

    modifier onlyDefender() {
        require(defender != address(0), "Defender not set");
        require(msg.sender == defender, "Caller not defender");
        _;
    }

    constructor(address defender_, address challenger_, address resultReceiver_) {
        defender = defender_;
        challenger = challenger_;
        resultReceiver = resultReceiver_;
    }

    /// @dev test helper to control pre-state.
    function setWinner(address winner_) external {
        winner = winner_;
    }

    function completeChallenge(bool result) external onlyDefender {
        require(winner != address(0), "Do not have winner");

        if (winner == challenger) {
            if (result) {
                IRollupCallback(resultReceiver).completeChallenge(challenger, defender);
                return;
            }
            winner = defender;
        }

        IRollupCallback(resultReceiver).completeChallenge(defender, challenger);
    }
}

contract DefenderCaller {
    function callComplete(ChallengeSettlementHarness challenge, bool result) external {
        challenge.completeChallenge(result);
    }
}
