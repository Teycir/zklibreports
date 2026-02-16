// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Minimal model for Mantle F-MAN-02 parity:
///         createAssertion immediately marks the newly created assertion confirmed.
contract RollupAssertionLifecycleHarness {
    struct AssertionData {
        bytes32 vmHash;
        uint64 inboxSize;
    }

    mapping(uint256 => AssertionData) public assertions;
    mapping(address => bool) public isOperator;

    uint256 public lastCreatedAssertionID;
    uint256 public lastResolvedAssertionID;
    uint256 public lastConfirmedAssertionID;

    event AssertionCreated(uint256 indexed assertionID, bytes32 vmHash, uint64 inboxSize);
    event AssertionConfirmed(uint256 indexed assertionID);

    constructor() {
        isOperator[msg.sender] = true;
    }

    function registerOperator(address operator) external {
        isOperator[operator] = true;
    }

    modifier operatorOnly() {
        if (!isOperator[msg.sender]) {
            revert("NotOperator");
        }
        _;
    }

    function createAssertion(bytes32 vmHash, uint64 inboxSize) external operatorOnly returns (uint256) {
        uint256 newAssertionID = ++lastCreatedAssertionID;
        assertions[newAssertionID] = AssertionData({vmHash: vmHash, inboxSize: inboxSize});

        // BUG PARITY: confirmation is advanced in the same call that creates the assertion.
        lastResolvedAssertionID++;
        lastConfirmedAssertionID = lastResolvedAssertionID;

        emit AssertionCreated(newAssertionID, vmHash, inboxSize);
        emit AssertionConfirmed(lastConfirmedAssertionID);
        return newAssertionID;
    }
}
