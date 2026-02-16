// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Like {
    function transfer(address _to, uint256 _amount) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _amount)
        external
        returns (bool);
    function approve(address _spender, uint256 _amount) external returns (bool);
    function balanceOf(address _account) external view returns (uint256);
}

/// @notice Minimal ERC20 used to exercise zero-amount transferFrom behavior.
contract MockZeroAwareToken {
    string public constant name = "Zero Aware";
    string public constant symbol = "ZERO";
    uint8 public constant decimals = 18;

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

/// @notice Recipient contract that accepts 2300-gas stipend dust transfers.
contract DustReceiver {
    receive() external payable {}
}

/// @notice Minimal token lookup model for preFill.
contract TokenRegistryPrefillModel {
    uint32 public immutable localDomain;
    mapping(bytes32 => address) public canonicalToRepresentation;

    constructor(uint32 _localDomain) {
        localDomain = _localDomain;
    }

    function setRepresentation(uint32 _domain, bytes32 _id, address _token)
        external
    {
        canonicalToRepresentation[keccak256(abi.encodePacked(_domain, _id))] =
            _token;
    }

    function mustHaveLocalToken(uint32 _domain, bytes32 _id)
        external
        view
        returns (address _token)
    {
        if (_domain == localDomain) {
            _token = address(uint160(uint256(_id)));
        } else {
            _token = canonicalToRepresentation[
                keccak256(abi.encodePacked(_domain, _id))
            ];
        }
        require(_token != address(0), "!token");
    }
}

/// @notice Bug model mirroring Nomad preFill behavior relevant to forged-message and dust-drain risk.
contract BridgeRouterPrefillDustBugModel {
    uint256 public constant PRE_FILL_FEE_NUMERATOR = 9995;
    uint256 public constant PRE_FILL_FEE_DENOMINATOR = 10000;
    uint256 public constant DUST_AMOUNT = 0.06 ether;

    TokenRegistryPrefillModel public immutable tokenRegistry;
    mapping(bytes32 => address) public liquidityProvider;
    uint256 public dustPoolWei;
    mapping(address => uint256) public dustedWei;

    constructor(address _tokenRegistry) {
        tokenRegistry = TokenRegistryPrefillModel(_tokenRegistry);
    }

    function seedDustPool(uint256 _amount) external {
        dustPoolWei += _amount;
    }

    function preFill(
        uint32 _origin,
        uint32 _nonce,
        uint32 _tokenDomain,
        bytes32 _tokenId,
        address _recipient,
        uint256 _amount,
        bool _isFastTransfer
    ) external {
        require(_isFastTransfer, "!fast transfer");

        bytes32 _id = _preFillId(
            _origin,
            _nonce,
            _tokenDomain,
            _tokenId,
            _recipient,
            _amount,
            _isFastTransfer
        );
        require(liquidityProvider[_id] == address(0), "!unfilled");
        liquidityProvider[_id] = msg.sender;

        address _token = tokenRegistry.mustHaveLocalToken(_tokenDomain, _tokenId);
        uint256 _afterFee = _applyPreFillFee(_amount);
        require(
            IERC20Like(_token).transferFrom(msg.sender, _recipient, _afterFee),
            "!transferFrom"
        );
        _dust(_recipient);
    }

    function _preFillId(
        uint32 _origin,
        uint32 _nonce,
        uint32 _tokenDomain,
        bytes32 _tokenId,
        address _recipient,
        uint256 _amount,
        bool _isFastTransfer
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _origin,
                    _nonce,
                    _tokenDomain,
                    _tokenId,
                    _recipient,
                    _amount,
                    _isFastTransfer
                )
            );
    }

    function _applyPreFillFee(uint256 _amount)
        internal
        pure
        returns (uint256)
    {
        return (_amount * PRE_FILL_FEE_NUMERATOR) / PRE_FILL_FEE_DENOMINATOR;
    }

    function _dust(address _recipient) internal {
        if (dustedWei[_recipient] < DUST_AMOUNT && dustPoolWei >= DUST_AMOUNT) {
            dustPoolWei -= DUST_AMOUNT;
            dustedWei[_recipient] += DUST_AMOUNT;
        }
    }
}

/// @notice Reference fix model: only explicitly approved transfer IDs can be prefilled.
contract BridgeRouterPrefillDustFixedModel {
    uint256 public constant PRE_FILL_FEE_NUMERATOR = 9995;
    uint256 public constant PRE_FILL_FEE_DENOMINATOR = 10000;
    uint256 public constant DUST_AMOUNT = 0.06 ether;

    TokenRegistryPrefillModel public immutable tokenRegistry;
    mapping(bytes32 => address) public liquidityProvider;
    mapping(bytes32 => bool) public approvedPrefill;
    uint256 public dustPoolWei;
    mapping(address => uint256) public dustedWei;

    constructor(address _tokenRegistry) {
        tokenRegistry = TokenRegistryPrefillModel(_tokenRegistry);
    }

    function seedDustPool(uint256 _amount) external {
        dustPoolWei += _amount;
    }

    function approvePrefill(
        uint32 _origin,
        uint32 _nonce,
        uint32 _tokenDomain,
        bytes32 _tokenId,
        address _recipient,
        uint256 _amount,
        bool _isFastTransfer
    ) external {
        bytes32 _id = _preFillId(
            _origin,
            _nonce,
            _tokenDomain,
            _tokenId,
            _recipient,
            _amount,
            _isFastTransfer
        );
        approvedPrefill[_id] = true;
    }

    function preFill(
        uint32 _origin,
        uint32 _nonce,
        uint32 _tokenDomain,
        bytes32 _tokenId,
        address _recipient,
        uint256 _amount,
        bool _isFastTransfer
    ) external {
        require(_isFastTransfer, "!fast transfer");
        require(_amount > 0, "!amount");

        bytes32 _id = _preFillId(
            _origin,
            _nonce,
            _tokenDomain,
            _tokenId,
            _recipient,
            _amount,
            _isFastTransfer
        );
        require(approvedPrefill[_id], "!approved");
        require(liquidityProvider[_id] == address(0), "!unfilled");
        liquidityProvider[_id] = msg.sender;
        delete approvedPrefill[_id];

        address _token = tokenRegistry.mustHaveLocalToken(_tokenDomain, _tokenId);
        uint256 _afterFee = _applyPreFillFee(_amount);
        require(
            IERC20Like(_token).transferFrom(msg.sender, _recipient, _afterFee),
            "!transferFrom"
        );
        _dust(_recipient);
    }

    function _preFillId(
        uint32 _origin,
        uint32 _nonce,
        uint32 _tokenDomain,
        bytes32 _tokenId,
        address _recipient,
        uint256 _amount,
        bool _isFastTransfer
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _origin,
                    _nonce,
                    _tokenDomain,
                    _tokenId,
                    _recipient,
                    _amount,
                    _isFastTransfer
                )
            );
    }

    function _applyPreFillFee(uint256 _amount)
        internal
        pure
        returns (uint256)
    {
        return (_amount * PRE_FILL_FEE_NUMERATOR) / PRE_FILL_FEE_DENOMINATOR;
    }

    function _dust(address _recipient) internal {
        if (dustedWei[_recipient] < DUST_AMOUNT && dustPoolWei >= DUST_AMOUNT) {
            dustPoolWei -= DUST_AMOUNT;
            dustedWei[_recipient] += DUST_AMOUNT;
        }
    }
}
