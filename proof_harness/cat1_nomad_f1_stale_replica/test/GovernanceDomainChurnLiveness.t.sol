// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    GovernanceDomainChurnBugModel,
    GovernanceDomainChurnFixedModel
} from "../src/GovernanceDomainChurnHarness.sol";

contract GovernanceDomainChurnLivenessTest {
    uint32 internal constant DOMAIN = 1111;
    bytes32 internal constant ROUTER = bytes32(uint256(0xA11CE));

    function _assertTrue(bool _condition, string memory _message) internal pure {
        require(_condition, _message);
    }

    /// @notice Witness:
    /// remove+readd churn leaves holes, so dispatch scans historical length instead of active domain count.
    function test_churn_creates_scan_overhead_in_bug_model() public {
        GovernanceDomainChurnBugModel bug = new GovernanceDomainChurnBugModel();
        bug.setRouterLocal(DOMAIN, ROUTER);

        uint256 loops = 150;
        for (uint256 i = 0; i < loops; i++) {
            bug.setRouterLocal(DOMAIN, bytes32(0));
            bug.setRouterLocal(DOMAIN, ROUTER);
        }

        bug.dispatchAll();

        uint256 active = bug.activeDomainCount();
        uint256 scans = bug.lastScanCount();
        uint256 len = bug.domainsLength();

        _assertTrue(active == 1, "active domain count should be 1");
        _assertTrue(
            scans == len && scans == loops + 1,
            "scan count should equal inflated historical length"
        );
        _assertTrue(scans > active, "expected scan overhead from holes");
    }

    /// @notice Fixed control:
    /// dense removal keeps scan count equal to active domain count after churn.
    function test_fixed_model_keeps_dense_domain_list() public {
        GovernanceDomainChurnFixedModel fixedModel =
            new GovernanceDomainChurnFixedModel();
        fixedModel.setRouterLocal(DOMAIN, ROUTER);

        uint256 loops = 150;
        for (uint256 i = 0; i < loops; i++) {
            fixedModel.setRouterLocal(DOMAIN, bytes32(0));
            fixedModel.setRouterLocal(DOMAIN, ROUTER);
        }

        fixedModel.dispatchAll();

        uint256 active = fixedModel.activeDomainCount();
        uint256 scans = fixedModel.lastScanCount();
        uint256 len = fixedModel.domainsLength();

        _assertTrue(active == 1, "active domain count should be 1");
        _assertTrue(len == 1, "dense model length should remain 1");
        _assertTrue(scans == active, "scan should match active domains");
    }

    /// @notice Fuzz witness:
    /// with any positive churn count, bug model scan count exceeds active domains.
    function testFuzz_bug_churn_scan_overhead(uint8 loopsSeed) public {
        GovernanceDomainChurnBugModel bug = new GovernanceDomainChurnBugModel();
        bug.setRouterLocal(DOMAIN, ROUTER);

        uint256 loops = (loopsSeed % 100) + 1;
        for (uint256 i = 0; i < loops; i++) {
            bug.setRouterLocal(DOMAIN, bytes32(0));
            bug.setRouterLocal(DOMAIN, ROUTER);
        }

        bug.dispatchAll();

        _assertTrue(
            bug.lastScanCount() > bug.activeDomainCount(),
            "expected bug-model scan overhead"
        );
    }
}
