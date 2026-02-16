// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Bug-parity model for TrailblazersBadgesS2.getBadge boundary checks.
contract TrailblazersBadgesS2Like {
    enum BadgeType {
        Ravers,
        Robots,
        Bouncers,
        Masters,
        Monks,
        Androids,
        Drummers,
        Shinto
    }

    enum MovementType {
        Undefined,
        Whale,
        Minnow
    }

    struct Badge {
        uint256 tokenId;
        BadgeType badgeType;
        MovementType movementType;
    }

    mapping(uint256 tokenId => Badge badge) internal badges;
    uint256 internal _totalSupply;

    error TOKEN_NOT_MINTED();

    function mintMock(uint8 _badgeType, uint8 _movementType) public returns (uint256 tokenId_) {
        tokenId_ = ++_totalSupply;
        badges[tokenId_] = Badge({
            tokenId: tokenId_,
            badgeType: BadgeType(uint256(_badgeType) % 8),
            movementType: MovementType(uint256(_movementType) % 3)
        });
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function getBadge(uint256 _tokenId) external view returns (Badge memory) {
        // Bug parity with TrailblazersBadgesS2.sol:180
        if (_tokenId < totalSupply()) {
            revert TOKEN_NOT_MINTED();
        }
        return badges[_tokenId];
    }
}