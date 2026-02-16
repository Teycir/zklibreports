// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract ChallengeBindingRollupHarness {
    struct Staker {
        bool isStaked;
        uint256 amountStaked;
        uint256 assertionID;
        address operator;
        address currentChallenge;
    }

    struct ChallengeCtx {
        bool completed;
        address challengeAddress;
        address defenderAddress;
        address challengerAddress;
        uint256 defenderAssertionID;
        uint256 challengerAssertionID;
    }

    mapping(address => Staker) public stakers; // staker -> state
    mapping(address => address) public registers; // operator -> staker
    mapping(uint256 => uint256) public assertionParent; // assertion id -> parent id
    mapping(address => uint256) public withdrawableFunds; // staker -> withdrawable amount

    uint256 public baseStakeAmount = 1 ether;
    uint256 public lastCreatedAssertionID;
    uint256 public lastConfirmedAssertionID;
    ChallengeCtx public challengeCtx;

    function seedAssertion(uint256 assertionID, uint256 parentID) external {
        assertionParent[assertionID] = parentID;
        if (assertionID > lastCreatedAssertionID) {
            lastCreatedAssertionID = assertionID;
        }
    }

    function setLastConfirmedAssertionID(uint256 id) external {
        lastConfirmedAssertionID = id;
    }

    function seedStaker(address operator, address staker, uint256 assertionID, uint256 amount) external {
        registers[operator] = staker;
        stakers[staker] =
            Staker({isStaked: true, amountStaked: amount, assertionID: assertionID, operator: operator, currentChallenge: address(0)});
    }

    modifier operatorOnly() {
        if (registers[msg.sender] == address(0)) {
            revert("NotOperator");
        }
        _;
    }

    function challengeAssertion(address[2] calldata players, uint256[2] calldata assertionIDs)
        external
        operatorOnly
        returns (address)
    {
        uint256 defenderAssertionID = assertionIDs[0];
        uint256 challengerAssertionID = assertionIDs[1];

        if (defenderAssertionID >= challengerAssertionID) {
            revert("WrongOrder");
        }
        if (challengerAssertionID > lastCreatedAssertionID) {
            revert("UnproposedAssertion");
        }
        if (lastConfirmedAssertionID >= defenderAssertionID) {
            revert("AssertionAlreadyResolved");
        }
        uint256 parentID = assertionParent[defenderAssertionID];
        if (parentID != assertionParent[challengerAssertionID]) {
            revert("DifferentParent");
        }

        address defender = players[0];
        address challenger = players[1];
        require(defender != challenger, "defender and challenge must not equal");

        address defenderStaker = registers[defender];
        address challengerStaker = registers[challenger];
        _requireUnchallengedStaker(defenderStaker);
        _requireUnchallengedStaker(challengerStaker);

        // BUG PARITY: no check that stakers are actually staked on defenderAssertionID/challengerAssertionID.
        ChallengeBindingStub challenge = new ChallengeBindingStub(address(this));
        address challengeAddr = address(challenge);
        stakers[challengerStaker].currentChallenge = challengeAddr;
        stakers[defenderStaker].currentChallenge = challengeAddr;

        challengeCtx = ChallengeCtx({
            completed: false,
            challengeAddress: challengeAddr,
            defenderAddress: defender,
            challengerAddress: challenger,
            defenderAssertionID: defenderAssertionID,
            challengerAssertionID: challengerAssertionID
        });
        return challengeAddr;
    }

    function completeChallenge(address winnerOperator, address loserOperator) external operatorOnly {
        address winnerStaker = registers[winnerOperator];
        address loserStaker = registers[loserOperator];
        _requireStaked(loserStaker);

        address challenge = _getChallenge(winnerStaker, loserStaker);
        if (msg.sender != challenge) {
            revert("NotChallenge");
        }

        uint256 loserStake = stakers[loserStaker].amountStaked;
        uint256 amountWon;
        if (loserStake > baseStakeAmount) {
            withdrawableFunds[loserStaker] += (loserStake - baseStakeAmount);
            amountWon = baseStakeAmount;
        } else {
            amountWon = loserStake;
        }

        stakers[winnerStaker].amountStaked += amountWon;
        stakers[winnerStaker].currentChallenge = address(0);

        delete registers[stakers[loserStaker].operator];
        delete stakers[loserStaker];
        challengeCtx.completed = true;
    }

    function _requireStaked(address stakerAddress) private view {
        if (!stakers[stakerAddress].isStaked) {
            revert("NotStaked");
        }
    }

    function _requireUnchallengedStaker(address stakerAddress) private view {
        _requireStaked(stakerAddress);
        if (stakers[stakerAddress].currentChallenge != address(0)) {
            revert("ChallengedStaker");
        }
    }

    function _getChallenge(address staker1Address, address staker2Address) private view returns (address) {
        address challenge = stakers[staker1Address].currentChallenge;
        if (challenge == address(0)) {
            revert("NotInChallenge");
        }
        if (challenge != stakers[staker2Address].currentChallenge) {
            revert("InDifferentChallenge");
        }
        return challenge;
    }
}

contract ChallengeBindingStub {
    ChallengeBindingRollupHarness public immutable rollup;

    constructor(address rollupAddress) {
        rollup = ChallengeBindingRollupHarness(rollupAddress);
    }

    function settle(address winnerOperator, address loserOperator) external {
        rollup.completeChallenge(winnerOperator, loserOperator);
    }
}
