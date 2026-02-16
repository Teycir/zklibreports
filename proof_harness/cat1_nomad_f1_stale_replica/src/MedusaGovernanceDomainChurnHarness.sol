// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    GovernanceDomainChurnBugModel,
    GovernanceDomainChurnFixedModel
} from "./GovernanceDomainChurnHarness.sol";

/// @notice Stateful harness for domain-churn scan-overhead behavior.
contract MedusaGovernanceDomainChurnHarness {
    GovernanceDomainChurnBugModel public bug;
    GovernanceDomainChurnFixedModel public fixedModel;

    uint32 public constant DOMAIN = 1111;
    bytes32 public constant ROUTER = bytes32(uint256(0xA11CE));

    bool public bugScanOverheadObserved;
    bool public fixedScanOverheadObserved;

    constructor() {
        bug = new GovernanceDomainChurnBugModel();
        fixedModel = new GovernanceDomainChurnFixedModel();
        bug.setRouterLocal(DOMAIN, ROUTER);
        fixedModel.setRouterLocal(DOMAIN, ROUTER);
    }

    function action_churn(uint8 _loopsSeed) external {
        uint256 loops = (_loopsSeed % 40) + 1;
        for (uint256 i = 0; i < loops; i++) {
            bug.setRouterLocal(DOMAIN, bytes32(0));
            bug.setRouterLocal(DOMAIN, ROUTER);

            fixedModel.setRouterLocal(DOMAIN, bytes32(0));
            fixedModel.setRouterLocal(DOMAIN, ROUTER);
        }
    }

    function action_dispatch() external {
        bug.dispatchAll();
        fixedModel.dispatchAll();

        if (bug.lastScanCount() > bug.activeDomainCount()) {
            bugScanOverheadObserved = true;
        }
        if (fixedModel.lastScanCount() > fixedModel.activeDomainCount()) {
            fixedScanOverheadObserved = true;
        }
    }

    /// @notice Dispatch scans should track active domains (not historical holes).
    function property_dispatch_scan_tracks_active_domains()
        external
        view
        returns (bool)
    {
        return !bugScanOverheadObserved;
    }

    /// @notice Fixed model should not accumulate scan overhead from churn.
    function property_fixed_model_avoids_scan_overhead()
        external
        view
        returns (bool)
    {
        return !fixedScanOverheadObserved;
    }

    /// @notice Echidna-compatible alias.
    function echidna_dispatch_scan_tracks_active_domains()
        external
        view
        returns (bool)
    {
        return !bugScanOverheadObserved;
    }
}
