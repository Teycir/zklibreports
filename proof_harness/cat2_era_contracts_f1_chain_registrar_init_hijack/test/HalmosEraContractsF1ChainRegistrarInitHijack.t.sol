// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    EraContractsF1SimpleProxy,
    ChainRegistrarLike,
    ChainRegistrarInitAttacker,
    IChainRegistrarLike,
    MockERC20
} from "../src/EraContractsF1ChainRegistrarInitHijackHarness.sol";

/// @notice Halmos check for ChainRegistrar initializer takeover and proposer top-up diversion.
contract HalmosEraContractsF1ChainRegistrarInitHijack {
    function check_attacker_cannot_drain_proposer_topups_via_initialize_hijack() public {
        address admin = address(this);
        address attackerCollector = address(0xCAFE);

        ChainRegistrarLike implementation = new ChainRegistrarLike();
        EraContractsF1SimpleProxy proxy = new EraContractsF1SimpleProxy(admin);
        IChainRegistrarLike registrar = IChainRegistrarLike(address(proxy));
        ChainRegistrarInitAttacker attacker = new ChainRegistrarInitAttacker();
        MockERC20 token = new MockERC20();

        proxy.upgradeTo(address(implementation));
        attacker.hijack(address(proxy), address(0xB0B), address(0xD3E10F), address(attacker));
        attacker.changeDeployer(address(proxy), attackerCollector);

        token.mint(address(this), 100 ether);
        token.approve(address(proxy), type(uint256).max);
        registrar.proposeChainRegistration(7, address(token), 10, 1);

        assert(token.balanceOf(attackerCollector) == 0);
    }
}
