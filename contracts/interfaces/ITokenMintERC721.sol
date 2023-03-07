// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

interface ITokenMintERC721 is IERC165Upgradeable {
    function getTokenCounter() external view returns (uint256 tokenId);

    function mint(address receiver, string memory uri) external;

    function mintBatch(address receiver, string[] memory newUris) external;

    function mintWithRoyalties(
        address receiver,
        string memory uri,
        uint96 _feeNumerator
    ) external;

    function mintBatchWithRoyalties(
        address receiver,
        string[] memory newUris,
        uint96 _feeNumerator
    ) external;
}
