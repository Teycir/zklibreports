// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice ERC20-like token that intentionally omits decimals/symbol/name.
contract MockNoMetadataTokenW {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address _to, uint256 _amount) external {
        balanceOf[_to] += _amount;
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        allowance[msg.sender][_spender] = _amount;
        return true;
    }

    function transfer(address _to, uint256 _amount) external returns (bool) {
        uint256 _bal = balanceOf[msg.sender];
        require(_bal >= _amount, "!balance");
        unchecked {
            balanceOf[msg.sender] = _bal - _amount;
        }
        balanceOf[_to] += _amount;
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount)
        external
        returns (bool)
    {
        uint256 _allowed = allowance[_from][msg.sender];
        require(_allowed >= _amount, "!allowance");
        uint256 _bal = balanceOf[_from];
        require(_bal >= _amount, "!balance");
        unchecked {
            allowance[_from][msg.sender] = _allowed - _amount;
            balanceOf[_from] = _bal - _amount;
        }
        balanceOf[_to] += _amount;
        return true;
    }
}

/// @notice Metadata-compliant token control.
contract MockMetadataTokenW is MockNoMetadataTokenW {
    function decimals() external pure returns (uint8) {
        return 18;
    }

    function symbol() external pure returns (string memory) {
        return "META";
    }

    function name() external pure returns (string memory) {
        return "Metadata Token";
    }
}

/// @notice Model mirroring Wormhole Bridge metadata reads:
/// staticcall + abi.decode without checking call success.
contract BridgeMetadataBugModel {
    function attestToken(address _token)
        external
        view
        returns (uint8 _decimals, bytes32 _symbol, bytes32 _name)
    {
        (, bytes memory queriedDecimals) =
            _token.staticcall(abi.encodeWithSignature("decimals()"));
        (, bytes memory queriedSymbol) =
            _token.staticcall(abi.encodeWithSignature("symbol()"));
        (, bytes memory queriedName) =
            _token.staticcall(abi.encodeWithSignature("name()"));

        _decimals = abi.decode(queriedDecimals, (uint8));
        string memory symbolString = abi.decode(queriedSymbol, (string));
        string memory nameString = abi.decode(queriedName, (string));

        assembly {
            _symbol := mload(add(symbolString, 32))
            _name := mload(add(nameString, 32))
        }
    }

    function transferTokens(address _token, uint256 _amount)
        external
        view
        returns (uint256 _normalized)
    {
        (, bytes memory queriedDecimals) =
            _token.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 decimals = abi.decode(queriedDecimals, (uint8));
        _normalized = _deNormalize(_normalize(_amount, decimals), decimals);
    }

    function _normalize(uint256 _amount, uint8 _decimals)
        internal
        pure
        returns (uint256)
    {
        if (_decimals > 8) {
            return _amount / (10 ** (_decimals - 8));
        }
        return _amount;
    }

    function _deNormalize(uint256 _amount, uint8 _decimals)
        internal
        pure
        returns (uint256)
    {
        if (_decimals > 8) {
            return _amount * (10 ** (_decimals - 8));
        }
        return _amount;
    }
}

/// @notice Reference fix model:
/// tolerate missing metadata methods by falling back to safe defaults.
contract BridgeMetadataFixedModel {
    bytes32 internal constant UNKNOWN = bytes32("UNKNOWN");

    function attestToken(address _token)
        external
        view
        returns (uint8 _decimals, bytes32 _symbol, bytes32 _name)
    {
        _decimals = _safeDecimals(_token);
        _symbol = _safeSymbol(_token);
        _name = _safeName(_token);
    }

    function transferTokens(address _token, uint256 _amount)
        external
        view
        returns (uint256 _normalized)
    {
        uint8 decimals = _safeDecimals(_token);
        _normalized = _deNormalize(_normalize(_amount, decimals), decimals);
    }

    function _safeDecimals(address _token) internal view returns (uint8) {
        (bool ok, bytes memory data) =
            _token.staticcall(abi.encodeWithSignature("decimals()"));
        if (!ok || data.length < 32) return 18;
        return abi.decode(data, (uint8));
    }

    function _safeSymbol(address _token) internal view returns (bytes32 out) {
        (bool ok, bytes memory data) =
            _token.staticcall(abi.encodeWithSignature("symbol()"));
        if (!ok || data.length < 64) return UNKNOWN;
        try this.decodeString(data) returns (string memory s) {
            assembly {
                out := mload(add(s, 32))
            }
        } catch {
            out = UNKNOWN;
        }
    }

    function _safeName(address _token) internal view returns (bytes32 out) {
        (bool ok, bytes memory data) =
            _token.staticcall(abi.encodeWithSignature("name()"));
        if (!ok || data.length < 64) return UNKNOWN;
        try this.decodeString(data) returns (string memory s) {
            assembly {
                out := mload(add(s, 32))
            }
        } catch {
            out = UNKNOWN;
        }
    }

    function decodeString(bytes memory data) external pure returns (string memory) {
        return abi.decode(data, (string));
    }

    function _normalize(uint256 _amount, uint8 _decimals)
        internal
        pure
        returns (uint256)
    {
        if (_decimals > 8) {
            return _amount / (10 ** (_decimals - 8));
        }
        return _amount;
    }

    function _deNormalize(uint256 _amount, uint8 _decimals)
        internal
        pure
        returns (uint256)
    {
        if (_decimals > 8) {
            return _amount * (10 ** (_decimals - 8));
        }
        return _amount;
    }
}

