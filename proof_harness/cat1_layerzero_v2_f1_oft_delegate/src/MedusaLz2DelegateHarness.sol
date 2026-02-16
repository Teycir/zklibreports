// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    EndpointDelegateAuthModel,
    BuggyOAppOwnershipModel,
    FixedOAppOwnershipModel
} from "./LayerZeroV2Harness.sol";

/// @notice Stateful specialist-fuzz harness for delegate persistence after ownership transfer.
contract MedusaLz2DelegateHarness {
    EndpointDelegateAuthModel public bugEndpoint;
    EndpointDelegateAuthModel public fixedEndpoint;
    BuggyOAppOwnershipModel public bugOApp;
    FixedOAppOwnershipModel public fixedOApp;

    address public constant NEW_OWNER = address(0xB0B);

    bool public bugTransferred;
    bool public fixedTransferred;
    bool public bugStaleDelegateSucceededAfterTransfer;
    bool public fixedStaleDelegateSucceededAfterTransfer;

    constructor() {
        bugEndpoint = new EndpointDelegateAuthModel();
        fixedEndpoint = new EndpointDelegateAuthModel();

        bugOApp = new BuggyOAppOwnershipModel(address(bugEndpoint), address(this));
        fixedOApp = new FixedOAppOwnershipModel(address(fixedEndpoint), address(this));
    }

    function action_bug_transfer_ownership() external {
        if (bugTransferred) return;
        bugOApp.transferOwnership(NEW_OWNER);
        bugTransferred = true;
    }

    function action_fixed_transfer_ownership() external {
        if (fixedTransferred) return;
        fixedOApp.transferOwnership(NEW_OWNER);
        fixedTransferred = true;
    }

    function action_bug_try_stale_delegate_reconfigure(uint16 eidSeed) external {
        uint32 eid = uint32(eidSeed) + 1;
        try bugEndpoint.setSendLibrary(address(bugOApp), eid, bugEndpoint.BLOCKED_LIBRARY()) {
            if (bugTransferred) {
                bugStaleDelegateSucceededAfterTransfer = true;
            }
        } catch {}
    }

    function action_fixed_try_stale_delegate_reconfigure(uint16 eidSeed) external {
        uint32 eid = uint32(eidSeed) + 1;
        try fixedEndpoint.setSendLibrary(address(fixedOApp), eid, fixedEndpoint.BLOCKED_LIBRARY()) {
            if (fixedTransferred) {
                fixedStaleDelegateSucceededAfterTransfer = true;
            }
        } catch {}
    }

    function property_stale_delegate_cannot_reconfigure_bug_model() external view returns (bool) {
        return !bugStaleDelegateSucceededAfterTransfer;
    }

    function property_stale_delegate_cannot_reconfigure_fixed_model() external view returns (bool) {
        return !fixedStaleDelegateSucceededAfterTransfer;
    }

    function echidna_stale_delegate_cannot_reconfigure_bug_model() external view returns (bool) {
        return !bugStaleDelegateSucceededAfterTransfer;
    }
}

