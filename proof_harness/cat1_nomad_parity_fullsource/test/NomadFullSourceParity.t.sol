// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {BridgeRouter} from "../src/external/nomad-xapps/contracts/bridge/BridgeRouter.sol";
import {TokenRegistry} from "../src/external/nomad-xapps/contracts/bridge/TokenRegistry.sol";
import {
    MockBridgeTokenParity,
    MockNomadHome,
    MockXAppConnectionManager,
    ParityGovernanceRouter
} from "../src/ParitySupport.sol";

contract NomadFullSourceParityTest {
    uint32 internal constant REMOTE_A = 1000;
    uint32 internal constant REMOTE_B = 1001;
    uint32 internal constant LOCAL_DOMAIN = 2000;

    event log(string message);
    event log_named_uint(string key, uint256 val);

    struct GasSnap {
        uint256 loops;
        uint256 gasUsed;
        uint256 scans;
        uint256 active;
        uint256 dispatches;
    }

    function _assertTrue(bool condition, string memory reason) internal pure {
        require(condition, reason);
    }

    function _id(address token) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(token)));
    }

    function test_h1_full_source_parity_migrate_alias_sequence() public {
        MockNomadHome home = new MockNomadHome();
        MockXAppConnectionManager xcm =
            new MockXAppConnectionManager(LOCAL_DOMAIN, address(home));

        TokenRegistry registry = new TokenRegistry();
        registry.initialize(address(0xBEEF), address(xcm));

        BridgeRouter router = new BridgeRouter();
        router.initialize(address(registry), address(xcm));

        MockBridgeTokenParity oldRepr = new MockBridgeTokenParity();
        MockBridgeTokenParity currentB = new MockBridgeTokenParity();

        address user = address(this);
        uint256 amount = 250 ether;

        // Canonical A -> old representation.
        registry.enrollCustom(REMOTE_A, _id(address(0xA11CE)), address(oldRepr));
        // Alias old representation to canonical B, then rotate B to currentB.
        registry.enrollCustom(REMOTE_B, _id(address(0xB0B)), address(oldRepr));
        registry.enrollCustom(REMOTE_B, _id(address(0xB0B)), address(currentB));

        oldRepr.mint(user, amount);
        _assertTrue(
            oldRepr.balanceOf(user) == amount,
            "expected legacy representation balance"
        );

        address migratedTarget = registry.oldReprToCurrentRepr(address(oldRepr));
        _assertTrue(
            migratedTarget == address(currentB),
            "old repr should resolve to canonical-B current repr"
        );

        // Full-source BridgeRouter.migrate execution.
        router.migrate(address(oldRepr));

        _assertTrue(oldRepr.balanceOf(user) == 0, "legacy repr should be burned");
        _assertTrue(
            currentB.balanceOf(user) == amount,
            "current B repr should be minted"
        );

        (uint32 dom, bytes32 id) = registry.getTokenId(address(currentB));
        _assertTrue(dom == REMOTE_B, "token domain should resolve to canonical B");
        _assertTrue(
            id == _id(address(0xB0B)),
            "token id should resolve to canonical B id"
        );
    }

    function _profileLevel(uint256 loops) internal returns (GasSnap memory snap) {
        MockNomadHome home = new MockNomadHome();
        MockXAppConnectionManager xcm =
            new MockXAppConnectionManager(LOCAL_DOMAIN, address(home));
        ParityGovernanceRouter router = new ParityGovernanceRouter(LOCAL_DOMAIN, 50);
        router.initialize(address(xcm), address(this));

        bytes32 r = bytes32(uint256(0x1234));
        bytes32 r2 = bytes32(uint256(0x5678));

        // Seed one active remote domain.
        router.setRouterLocal(REMOTE_A, r);

        for (uint256 i = 0; i < loops; i++) {
            router.setRouterLocal(REMOTE_A, bytes32(0));
            router.setRouterLocal(REMOTE_A, r);
        }

        uint256 g0 = gasleft();
        router.testSetRouterGlobal(REMOTE_A, r2);
        uint256 g1 = gasleft();

        snap.loops = loops;
        snap.gasUsed = g0 - g1;
        snap.scans = router.domainsLength();
        snap.active = router.activeDomains();
        snap.dispatches = home.dispatchCount();
    }

    function test_h2_full_source_parity_governance_domain_churn_gas_slope() public {
        uint256[] memory levels = new uint256[](9);
        levels[0] = 0;
        levels[1] = 10;
        levels[2] = 25;
        levels[3] = 50;
        levels[4] = 100;
        levels[5] = 200;
        levels[6] = 400;
        levels[7] = 800;
        levels[8] = 1200;

        uint256 baseline;
        uint256 prevGas;
        uint256 cross2x = type(uint256).max;
        uint256 cross3x = type(uint256).max;
        uint256 cross5x = type(uint256).max;

        emit log("nomad full-source governance domain-churn profile");

        for (uint256 i = 0; i < levels.length; i++) {
            GasSnap memory s = _profileLevel(levels[i]);
            emit log_named_uint("loops", s.loops);
            emit log_named_uint("gas_used", s.gasUsed);
            emit log_named_uint("scan_slots", s.scans);
            emit log_named_uint("active_domains", s.active);
            emit log_named_uint("dispatch_count", s.dispatches);

            _assertTrue(s.active == 1, "expected one active domain");
            _assertTrue(s.scans == s.loops + 1, "scan slots should track churn");

            if (i == 0) {
                baseline = s.gasUsed;
                prevGas = s.gasUsed;
            } else {
                _assertTrue(s.gasUsed > prevGas, "gas should increase with churn");
                prevGas = s.gasUsed;
            }

            if (cross2x == type(uint256).max && s.gasUsed >= baseline * 2) {
                cross2x = s.loops;
            }
            if (cross3x == type(uint256).max && s.gasUsed >= baseline * 3) {
                cross3x = s.loops;
            }
            if (cross5x == type(uint256).max && s.gasUsed >= baseline * 5) {
                cross5x = s.loops;
            }
        }

        emit log_named_uint("baseline_gas", baseline);
        emit log_named_uint("cross_2x_baseline_loops", cross2x);
        emit log_named_uint("cross_3x_baseline_loops", cross3x);
        emit log_named_uint("cross_5x_baseline_loops", cross5x);

        _assertTrue(cross2x != type(uint256).max, "2x crossing expected");
        _assertTrue(cross3x != type(uint256).max, "3x crossing expected");
        _assertTrue(cross5x != type(uint256).max, "5x crossing expected");
        _assertTrue(cross2x <= cross3x, "2x should occur before 3x");
        _assertTrue(cross3x <= cross5x, "3x should occur before 5x");
    }
}

