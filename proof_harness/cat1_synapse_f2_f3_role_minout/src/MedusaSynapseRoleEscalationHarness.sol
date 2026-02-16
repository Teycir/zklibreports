// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ISynapseRoleTarget,
    RoleCaller,
    SynapseRoleEscalationBugModel,
    SynapseRoleEscalationFixedModel
} from "./SynapseRoleAndMinOutHarness.sol";

/// @notice Specialist-fuzz harness for F2 role-escalation blast radius.
contract MedusaSynapseRoleEscalationHarness {
    uint256 internal constant INITIAL_COLLATERAL = 1_000 ether;

    RoleCaller public adminCaller;
    RoleCaller public governanceCaller;
    RoleCaller public attackerCaller;

    SynapseRoleEscalationBugModel public bugModel;
    SynapseRoleEscalationFixedModel public fixedModel;

    bool public bugBroken;
    bool public fixedBroken;

    constructor() {
        adminCaller = new RoleCaller();
        governanceCaller = new RoleCaller();
        attackerCaller = new RoleCaller();

        bugModel = new SynapseRoleEscalationBugModel(address(adminCaller), INITIAL_COLLATERAL);
        fixedModel = new SynapseRoleEscalationFixedModel(address(adminCaller), address(governanceCaller), INITIAL_COLLATERAL);

        _refreshBug();
        _refreshFixed();
    }

    function action_bug_admin_grants_attacker_node() external {
        try adminCaller.callGrant(ISynapseRoleTarget(address(bugModel)), address(attackerCaller)) {} catch {}
        _refreshBug();
    }

    function action_bug_attacker_withdraw(uint96 amountSeed) external {
        uint256 bal = bugModel.collateral();
        if (bal == 0) return;
        uint256 amount = (uint256(amountSeed) % bal) + 1;
        try attackerCaller.callWithdraw(ISynapseRoleTarget(address(bugModel)), payable(address(this)), amount) {} catch {}
        _refreshBug();
    }

    function action_fixed_admin_grants_attacker_node() external {
        try adminCaller.callGrant(ISynapseRoleTarget(address(fixedModel)), address(attackerCaller)) {} catch {}
        _refreshFixed();
    }

    function action_fixed_attacker_withdraw(uint96 amountSeed) external {
        uint256 bal = fixedModel.collateral();
        if (bal == 0) return;
        uint256 amount = (uint256(amountSeed) % bal) + 1;
        try attackerCaller.callWithdraw(ISynapseRoleTarget(address(fixedModel)), payable(address(this)), amount) {} catch {}
        _refreshFixed();
    }

    function _refreshBug() internal {
        if (bugModel.collateral() < INITIAL_COLLATERAL) {
            bugBroken = true;
        }
    }

    function _refreshFixed() internal {
        if (fixedModel.collateral() < INITIAL_COLLATERAL) {
            fixedBroken = true;
        }
    }

    function property_bug_admin_compromise_cannot_reduce_collateral() external view returns (bool) {
        return !bugBroken;
    }

    function property_fixed_admin_compromise_cannot_reduce_collateral() external view returns (bool) {
        return !fixedBroken;
    }

    function echidna_bug_admin_compromise_cannot_reduce_collateral() external view returns (bool) {
        return !bugBroken;
    }
}
