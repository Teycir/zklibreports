// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Bug model mirroring GovernanceRouter domain list behavior:
/// domain removal deletes array slot (hole), iteration scans full historical length.
contract GovernanceDomainChurnBugModel {
    mapping(uint32 => bytes32) public routers;
    uint32[] public domains;

    uint256 public lastScanCount;
    uint256 public lastDispatchCount;

    function setRouterLocal(uint32 _domain, bytes32 _router) external {
        bytes32 _prev = routers[_domain];
        if (_router == bytes32(0)) {
            _removeDomain(_domain);
            delete routers[_domain];
        } else {
            if (_prev == bytes32(0)) {
                domains.push(_domain);
            }
            routers[_domain] = _router;
        }
    }

    function dispatchAll() external {
        uint256 _scan;
        uint256 _dispatch;
        for (uint256 i = 0; i < domains.length; i++) {
            _scan++;
            uint32 _d = domains[i];
            if (_d != 0 && routers[_d] != bytes32(0)) {
                _dispatch++;
            }
        }
        lastScanCount = _scan;
        lastDispatchCount = _dispatch;
    }

    function activeDomainCount() public view returns (uint256 _active) {
        for (uint256 i = 0; i < domains.length; i++) {
            uint32 _d = domains[i];
            if (_d != 0 && routers[_d] != bytes32(0)) {
                _active++;
            }
        }
    }

    function domainsLength() external view returns (uint256) {
        return domains.length;
    }

    function _removeDomain(uint32 _domain) internal {
        for (uint256 i = 0; i < domains.length; i++) {
            if (domains[i] == _domain) {
                delete domains[i];
                return;
            }
        }
    }
}

/// @notice Reference fix model using dense array + index mapping (swap-and-pop).
contract GovernanceDomainChurnFixedModel {
    mapping(uint32 => bytes32) public routers;
    uint32[] public domains;
    mapping(uint32 => uint256) public domainIndexPlusOne;

    uint256 public lastScanCount;
    uint256 public lastDispatchCount;

    function setRouterLocal(uint32 _domain, bytes32 _router) external {
        bytes32 _prev = routers[_domain];
        if (_router == bytes32(0)) {
            if (_prev != bytes32(0)) {
                _removeDense(_domain);
                delete routers[_domain];
            }
        } else {
            if (_prev == bytes32(0)) {
                domains.push(_domain);
                domainIndexPlusOne[_domain] = domains.length;
            }
            routers[_domain] = _router;
        }
    }

    function dispatchAll() external {
        uint256 _scan;
        uint256 _dispatch;
        for (uint256 i = 0; i < domains.length; i++) {
            _scan++;
            uint32 _d = domains[i];
            if (routers[_d] != bytes32(0)) {
                _dispatch++;
            }
        }
        lastScanCount = _scan;
        lastDispatchCount = _dispatch;
    }

    function activeDomainCount() public view returns (uint256 _active) {
        for (uint256 i = 0; i < domains.length; i++) {
            if (routers[domains[i]] != bytes32(0)) {
                _active++;
            }
        }
    }

    function domainsLength() external view returns (uint256) {
        return domains.length;
    }

    function _removeDense(uint32 _domain) internal {
        uint256 _idxPlus = domainIndexPlusOne[_domain];
        if (_idxPlus == 0) return;
        uint256 _idx = _idxPlus - 1;
        uint256 _last = domains.length - 1;
        if (_idx != _last) {
            uint32 _moved = domains[_last];
            domains[_idx] = _moved;
            domainIndexPlusOne[_moved] = _idx + 1;
        }
        domains.pop();
        delete domainIndexPlusOne[_domain];
    }
}
