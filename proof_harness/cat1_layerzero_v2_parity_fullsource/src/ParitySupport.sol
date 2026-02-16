// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { OFTAdapter } from "../external/lz-evm-oapp-contracts/oft/OFTAdapter.sol";
import { EndpointV2 } from "../external/lz-evm-protocol-v2/contracts/EndpointV2.sol";
import { MessagingParams, MessagingReceipt } from "../external/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract MockInboundFeeToken {
    string public constant name = "Inbound Fee Token";
    string public constant symbol = "IFT";
    uint8 public constant decimals = 18;

    address public immutable feeCollector;
    uint16 public immutable inboundFeeBps;

    address public feeTarget;
    bool public feeTargetLocked;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(address _feeCollector, uint16 _inboundFeeBps) {
        require(_feeCollector != address(0), "collector=0");
        require(_inboundFeeBps <= 10_000, "bps too high");
        feeCollector = _feeCollector;
        inboundFeeBps = _inboundFeeBps;
    }

    function setFeeTarget(address _feeTarget) external {
        require(!feeTargetLocked, "fee target locked");
        require(_feeTarget != address(0), "target=0");
        feeTarget = _feeTarget;
        feeTargetLocked = true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (msg.sender != from) {
            uint256 allowed = allowance[from][msg.sender];
            require(allowed >= amount, "!allowance");
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        uint256 bal = balanceOf[from];
        require(bal >= amount, "!balance");
        unchecked {
            balanceOf[from] = bal - amount;
        }

        uint256 fee = 0;
        if (to == feeTarget && inboundFeeBps > 0) {
            fee = (amount * inboundFeeBps) / 10_000;
        }

        uint256 received = amount - fee;
        balanceOf[to] += received;
        if (fee > 0) {
            balanceOf[feeCollector] += fee;
        }
    }
}

contract ParityOFTAdapter is OFTAdapter {
    constructor(address _token, address _lzEndpoint, address _delegate) OFTAdapter(_token, _lzEndpoint, _delegate) {}

    function debit(
        uint256 _amountToSendLD,
        uint256 _minAmountToCreditLD,
        uint32 _dstEid
    ) external returns (uint256 amountDebitedLD, uint256 amountToCreditLD) {
        return _debit(msg.sender, _amountToSendLD, _minAmountToCreditLD, _dstEid);
    }
}

contract DelegateActor {
    function trySetSendLibrary(
        EndpointV2 endpoint,
        address oapp,
        uint32 eid,
        address lib
    ) external returns (bool) {
        try endpoint.setSendLibrary(oapp, eid, lib) {
            return true;
        } catch {
            return false;
        }
    }
}

contract OwnerActor {
    function rotateDelegate(ParityOFTAdapter adapter, address delegate) external {
        adapter.setDelegate(delegate);
    }
}

contract MockLzToken is ERC20 {
    constructor() ERC20("Mock LZ Token", "mLZ") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EndpointSendActor {
    function callSend(
        EndpointV2 endpoint,
        MessagingParams calldata params,
        address payable refundAddress
    ) external payable returns (MessagingReceipt memory receipt) {
        return endpoint.send{ value: msg.value }(params, refundAddress);
    }
}
