// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBridgeAssetLike {
    function transfer(address _to, uint256 _amount) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _amount)
        external
        returns (bool);
    function approve(address _spender, uint256 _amount) external returns (bool);
    function balanceOf(address _account) external view returns (uint256);
    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;
}

/// @notice Minimal ERC20-like canonical token.
contract MockCanonicalBridgeToken {
    string public constant name = "Canonical";
    string public constant symbol = "CAN";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address _to, uint256 _amount) external {
        balanceOf[_to] += _amount;
    }

    function burn(address _from, uint256 _amount) external {
        uint256 _bal = balanceOf[_from];
        require(_bal >= _amount, "!balance");
        unchecked {
            balanceOf[_from] = _bal - _amount;
        }
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

/// @notice Representation token with router-owned mint/burn.
contract MockRepresentationBridgeToken {
    address public immutable owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        balanceOf[_to] += _amount;
    }

    function burn(address _from, uint256 _amount) external onlyOwner {
        uint256 _bal = balanceOf[_from];
        require(_bal >= _amount, "!balance");
        unchecked {
            balanceOf[_from] = _bal - _amount;
        }
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

struct CanonicalTokenIdAlias {
    uint32 domain;
    bytes32 id;
}

abstract contract TokenRegistryAliasBaseModel {
    uint32 public immutable localDomain;

    mapping(address => CanonicalTokenIdAlias) public representationToCanonical;
    mapping(bytes32 => address) public canonicalToRepresentation;

    constructor(uint32 _localDomain) {
        localDomain = _localDomain;
    }

    function _hashTokenId(uint32 _domain, bytes32 _id)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_domain, _id));
    }

    function _setRepresentationToCanonical(
        uint32 _domain,
        bytes32 _id,
        address _representation
    ) internal {
        representationToCanonical[_representation] = CanonicalTokenIdAlias(
            _domain,
            _id
        );
    }

    function _setCanonicalToRepresentation(
        uint32 _domain,
        bytes32 _id,
        address _representation
    ) internal {
        canonicalToRepresentation[_hashTokenId(_domain, _id)] = _representation;
    }

    function enrollCustom(uint32 _domain, bytes32 _id, address _custom)
        external
        virtual;

    function getRepresentationAddress(uint32 _domain, bytes32 _id)
        public
        view
        returns (address)
    {
        return canonicalToRepresentation[_hashTokenId(_domain, _id)];
    }

    function getLocalAddress(uint32 _domain, bytes32 _id)
        public
        view
        returns (address _local)
    {
        if (_domain == localDomain) {
            _local = address(uint160(uint256(_id)));
        } else {
            _local = getRepresentationAddress(_domain, _id);
        }
    }

    function ensureLocalToken(uint32 _domain, bytes32 _id)
        external
        returns (address _local)
    {
        _local = getLocalAddress(_domain, _id);
        if (_local == address(0)) {
            require(_domain != localDomain, "!local");
            MockRepresentationBridgeToken _repr =
                new MockRepresentationBridgeToken(msg.sender);
            _local = address(_repr);
            _setRepresentationToCanonical(_domain, _id, _local);
            _setCanonicalToRepresentation(_domain, _id, _local);
        }
    }

    function getTokenId(address _local)
        external
        view
        returns (uint32 _domain, bytes32 _id)
    {
        CanonicalTokenIdAlias memory _canonical =
            representationToCanonical[_local];
        if (_canonical.domain == 0) {
            _domain = localDomain;
            _id = bytes32(uint256(uint160(_local)));
        } else {
            _domain = _canonical.domain;
            _id = _canonical.id;
        }
    }

    function oldReprToCurrentRepr(address _oldRepr)
        external
        view
        returns (address _currentRepr)
    {
        CanonicalTokenIdAlias memory _canonical =
            representationToCanonical[_oldRepr];
        require(_canonical.domain != 0, "!repr");
        _currentRepr = getRepresentationAddress(_canonical.domain, _canonical.id);
    }

    function isLocalOrigin(address _token) public view returns (bool) {
        if (representationToCanonical[_token].domain != 0) return false;
        uint256 _size;
        assembly {
            _size := extcodesize(_token)
        }
        return _size != 0;
    }
}

/// @notice Bug model: allows one custom representation to be enrolled for multiple canonical IDs.
contract TokenRegistryAliasBugModel is TokenRegistryAliasBaseModel {
    constructor(uint32 _localDomain) TokenRegistryAliasBaseModel(_localDomain) {}

    function enrollCustom(uint32 _domain, bytes32 _id, address _custom)
        external
        override
    {
        _setRepresentationToCanonical(_domain, _id, _custom);
        _setCanonicalToRepresentation(_domain, _id, _custom);
    }
}

/// @notice Reference fix model: reject aliasing one custom representation across different canonical IDs.
contract TokenRegistryAliasFixedModel is TokenRegistryAliasBaseModel {
    constructor(uint32 _localDomain) TokenRegistryAliasBaseModel(_localDomain) {}

    function enrollCustom(uint32 _domain, bytes32 _id, address _custom)
        external
        override
    {
        CanonicalTokenIdAlias memory _existing =
            representationToCanonical[_custom];
        if (_existing.domain != 0) {
            require(
                _existing.domain == _domain && _existing.id == _id,
                "!custom alias"
            );
        }
        _setRepresentationToCanonical(_domain, _id, _custom);
        _setCanonicalToRepresentation(_domain, _id, _custom);
    }
}

/// @notice Minimal cross-chain router model for token ID forwarding behavior.
contract BridgeRouterAliasModel {
    TokenRegistryAliasBaseModel public immutable tokenRegistry;
    BridgeRouterAliasModel public remoteRouter;

    mapping(address => uint256) public escrowed;

    constructor(address _tokenRegistry) {
        tokenRegistry = TokenRegistryAliasBaseModel(_tokenRegistry);
    }

    function setRemote(address _remote) external {
        remoteRouter = BridgeRouterAliasModel(_remote);
    }

    function seedCanonicalEscrow(address _token, uint256 _amount) external {
        IBridgeAssetLike(_token).mint(address(this), _amount);
        escrowed[_token] += _amount;
    }

    function send(address _token, uint256 _amount, address _recipient) external {
        require(_amount > 0, "!amount");
        require(address(remoteRouter) != address(0), "!remote");

        if (tokenRegistry.isLocalOrigin(_token)) {
            require(
                IBridgeAssetLike(_token).transferFrom(
                    msg.sender, address(this), _amount
                ),
                "!transferFrom"
            );
            escrowed[_token] += _amount;
        } else {
            IBridgeAssetLike(_token).burn(msg.sender, _amount);
        }

        (uint32 _domain, bytes32 _id) = tokenRegistry.getTokenId(_token);
        remoteRouter.receiveToken(_domain, _id, _amount, _recipient);
    }

    function receiveToken(
        uint32 _domain,
        bytes32 _id,
        uint256 _amount,
        address _recipient
    ) external {
        require(msg.sender == address(remoteRouter), "!remote sender");
        address _local = tokenRegistry.ensureLocalToken(_domain, _id);
        if (tokenRegistry.isLocalOrigin(_local)) {
            uint256 _escrow = escrowed[_local];
            require(_escrow >= _amount, "!escrow");
            unchecked {
                escrowed[_local] = _escrow - _amount;
            }
            require(
                IBridgeAssetLike(_local).transfer(_recipient, _amount),
                "!transfer"
            );
        } else {
            IBridgeAssetLike(_local).mint(_recipient, _amount);
        }
    }
}
