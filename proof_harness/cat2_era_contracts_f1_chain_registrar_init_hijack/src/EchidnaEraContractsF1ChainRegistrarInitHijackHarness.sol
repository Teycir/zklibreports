// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    EraContractsF1SimpleProxy,
    ChainRegistrarLike,
    ChainRegistrarInitAttacker,
    IChainRegistrarLike,
    MockERC20
} from "./EraContractsF1ChainRegistrarInitHijackHarness.sol";

/// @notice Echidna harness for ChainRegistrar initializer takeover and top-up diversion.
contract EchidnaEraContractsF1ChainRegistrarInitHijackHarness {
    EraContractsF1SimpleProxy public proxy;
    IChainRegistrarLike public registrar;
    ChainRegistrarInitAttacker public attacker;
    MockERC20 public token;

    address public attackerCollector;

    constructor() {
        attackerCollector = address(0xCAFE);

        ChainRegistrarLike implementation = new ChainRegistrarLike();
        proxy = new EraContractsF1SimpleProxy(address(this));
        proxy.upgradeTo(address(implementation));
        registrar = IChainRegistrarLike(address(proxy));
        attacker = new ChainRegistrarInitAttacker();

        token = new MockERC20();
        token.mint(address(this), 100 ether);
        token.approve(address(proxy), type(uint256).max);
    }

    function action_attacker_initialize() public {
        try attacker.hijack(address(proxy), address(0xB0B), address(0xD3E10F), address(attacker)) {} catch {}
    }

    function action_attacker_change_deployer() public {
        if (registrar.owner() != address(attacker)) {
            return;
        }
        try attacker.changeDeployer(address(proxy), attackerCollector) {} catch {}
    }

    function action_victim_propose_non_eth() public {
        try registrar.proposeChainRegistration(7, address(token), 10, 1) {} catch {}
    }

    function echidna_attacker_cannot_receive_proposer_topup() public view returns (bool) {
        return token.balanceOf(attackerCollector) == 0;
    }
}
