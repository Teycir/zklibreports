// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    IBridgeAssetLike,
    BridgeRouterAliasModel
} from "./TokenRegistryAliasSwapHarness.sol";

/// @notice BridgeRouter model including migrate behavior from Nomad BridgeRouter.
contract BridgeRouterMigrateAliasModel is BridgeRouterAliasModel {
    constructor(address _tokenRegistry) BridgeRouterAliasModel(_tokenRegistry) {}

    function migrate(address _oldRepr) external {
        address _currentRepr = tokenRegistry.oldReprToCurrentRepr(_oldRepr);
        require(_currentRepr != _oldRepr, "!different");

        IBridgeAssetLike _old = IBridgeAssetLike(_oldRepr);
        uint256 _bal = _old.balanceOf(msg.sender);
        _old.burn(msg.sender, _bal);
        IBridgeAssetLike(_currentRepr).mint(msg.sender, _bal);
    }
}
