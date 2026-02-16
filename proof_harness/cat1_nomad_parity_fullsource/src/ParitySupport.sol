// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {TestGovernanceRouter} from "./external/nomad-core/contracts/test/TestGovernanceRouter.sol";

interface IBridgeTokenLike {
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract MockNomadHome {
    uint256 public dispatchCount;

    event Dispatch(uint32 destination, bytes32 recipient, bytes message);

    function dispatch(uint32 destination, bytes32 recipient, bytes memory message)
        external
        returns (uint32)
    {
        dispatchCount += 1;
        emit Dispatch(destination, recipient, message);
        return uint32(dispatchCount);
    }
}

contract MockXAppConnectionManager {
    uint32 public immutable localDomain;
    address public home;

    mapping(address => bool) public replicas;

    constructor(uint32 _localDomain, address _home) {
        localDomain = _localDomain;
        home = _home;
    }

    function setHome(address _home) external {
        home = _home;
    }

    function setReplica(address _replica, bool _allowed) external {
        replicas[_replica] = _allowed;
    }

    function isReplica(address _replica) external view returns (bool) {
        return replicas[_replica];
    }
}

contract MockBridgeTokenParity is IBridgeTokenLike {
    mapping(address => uint256) public override balanceOf;

    function mint(address account, uint256 amount) external override {
        balanceOf[account] += amount;
    }

    function burn(address account, uint256 amount) external override {
        uint256 bal = balanceOf[account];
        require(bal >= amount, "!balance");
        balanceOf[account] = bal - amount;
    }
}

contract ParityGovernanceRouter is TestGovernanceRouter {
    constructor(uint32 _localDomain, uint256 _recoveryTimelock)
        TestGovernanceRouter(_localDomain, _recoveryTimelock)
    {}

    function domainsLength() external view returns (uint256) {
        return domains.length;
    }

    function activeDomains() external view returns (uint256 active) {
        for (uint256 i = 0; i < domains.length; i++) {
            uint32 d = domains[i];
            if (d != uint32(0) && routers[d] != bytes32(0)) {
                active += 1;
            }
        }
    }
}

