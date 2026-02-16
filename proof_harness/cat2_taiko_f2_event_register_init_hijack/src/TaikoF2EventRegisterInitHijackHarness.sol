// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IEventRegisterLike {
    function initialize() external;
    function owner() external view returns (address);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function createEvent(string calldata name) external;
    function grantEventManagerRole(address account) external;
    function revokeEventManagerRole(address account) external;
    function eventExists(uint256 eventId) external view returns (bool);
}

/// @notice EventRegister model preserving taiko-contracts bug parity:
///         deployment grants DEFAULT_ADMIN_ROLE in constructor, while initialize()
///         is a separate first-caller gate that assigns owner + EVENT_MANAGER_ROLE.
contract EventRegisterLike is IEventRegisterLike {
    bytes32 public constant DEFAULT_ADMIN_ROLE = bytes32(0);
    bytes32 public constant EVENT_MANAGER_ROLE = keccak256("EVENT_MANAGER_ROLE");

    bool internal initialized;
    address internal _owner;
    uint256 internal nextEventId;

    mapping(bytes32 => mapping(address => bool)) internal roles;
    mapping(uint256 => bool) internal exists;

    error AlreadyInitialized();
    error MissingRole();

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function initialize() external {
        if (initialized) revert AlreadyInitialized();
        initialized = true;
        _grantRole(EVENT_MANAGER_ROLE, msg.sender);
        _owner = msg.sender;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return roles[role][account];
    }

    function grantEventManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(EVENT_MANAGER_ROLE, account);
    }

    function revokeEventManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        roles[EVENT_MANAGER_ROLE][account] = false;
    }

    function createEvent(string calldata) external onlyRole(EVENT_MANAGER_ROLE) {
        exists[nextEventId] = true;
        nextEventId++;
    }

    function eventExists(uint256 eventId) external view returns (bool) {
        return exists[eventId];
    }

    modifier onlyRole(bytes32 role) {
        if (!roles[role][msg.sender]) revert MissingRole();
        _;
    }

    function _grantRole(bytes32 role, address account) internal {
        roles[role][account] = true;
    }
}
