// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    EraContractsF1SimpleProxy,
    ChainRegistrarLike,
    ChainRegistrarInitAttacker,
    IChainRegistrarLike,
    MockERC20
} from "./EraContractsF1ChainRegistrarInitHijackHarness.sol";

/// @notice Stateful Medusa harness for ChainRegistrar initializer takeover and top-up diversion.
contract MedusaEraContractsF1ChainRegistrarInitHijackHarness {
    EraContractsF1SimpleProxy public proxy;
    IChainRegistrarLike public registrar;
    ChainRegistrarInitAttacker public attacker;
    MockERC20 public token;

    address public attackerCollector;
    bool public initialized;
    bool public proposed;

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
        if (initialized) {
            return;
        }
        attacker.hijack(address(proxy), address(0xB0B), address(0xD3E10F), address(attacker));
        initialized = true;
    }

    function action_attacker_change_deployer() public {
        if (registrar.owner() != address(attacker)) {
            return;
        }
        attacker.changeDeployer(address(proxy), attackerCollector);
    }

    function action_victim_propose_non_eth() public {
        if (proposed) {
            return;
        }
        registrar.proposeChainRegistration(7, address(token), 10, 1);
        proposed = true;
    }

    function property_attacker_cannot_receive_proposer_topup() public view returns (bool) {
        return token.balanceOf(attackerCollector) == 0;
    }
}
