// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Buggy model of the Nomad XAppConnectionManager enrollment logic.
contract XAppConnectionManagerBug {
    address public owner;

    mapping(address => uint32) public replicaToDomain;
    mapping(uint32 => address) public domainToReplica;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    function ownerEnrollReplica(address _replica, uint32 _domain) external onlyOwner {
        // Mirrors the bug: unenrolls the new replica address instead of the current domain occupant.
        _unenrollReplica(_replica);
        replicaToDomain[_replica] = _domain;
        domainToReplica[_domain] = _replica;
    }

    function ownerUnenrollReplica(address _replica) external onlyOwner {
        _unenrollReplica(_replica);
    }

    function isReplica(address _replica) public view returns (bool) {
        return replicaToDomain[_replica] != 0;
    }

    function _unenrollReplica(address _replica) internal {
        uint32 currentDomain = replicaToDomain[_replica];
        domainToReplica[currentDomain] = address(0);
        replicaToDomain[_replica] = 0;
    }
}

/// @notice Fixed model for contrast in the proof harness.
contract XAppConnectionManagerFixed {
    address public owner;

    mapping(address => uint32) public replicaToDomain;
    mapping(uint32 => address) public domainToReplica;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    function ownerEnrollReplica(address _replica, uint32 _domain) external onlyOwner {
        address currentReplica = domainToReplica[_domain];
        if (currentReplica != address(0) && currentReplica != _replica) {
            _unenrollReplica(currentReplica);
        }

        uint32 oldDomain = replicaToDomain[_replica];
        if (oldDomain != 0 && oldDomain != _domain) {
            _unenrollReplica(_replica);
        }

        replicaToDomain[_replica] = _domain;
        domainToReplica[_domain] = _replica;
    }

    function ownerUnenrollReplica(address _replica) external onlyOwner {
        _unenrollReplica(_replica);
    }

    function isReplica(address _replica) public view returns (bool) {
        return replicaToDomain[_replica] != 0;
    }

    function _unenrollReplica(address _replica) internal {
        uint32 currentDomain = replicaToDomain[_replica];
        if (currentDomain != 0) {
            domainToReplica[currentDomain] = address(0);
            replicaToDomain[_replica] = 0;
        }
    }
}

