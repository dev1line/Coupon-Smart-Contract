// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

interface ITokenMintERC1155 is IERC165Upgradeable {
    function getTokenCounter() external view returns (uint256 tokenId);

    function mint(address receiver, uint256 amount, string memory uri) external;

    function mintBatch(
        address receiver,
        uint256[] memory amounts,
        string[] memory newUris
    ) external;

    function mintWithRoyalties(
        address receiver,
        uint256 amount,
        string memory newuri,
        uint96 _feeNumerator
    ) external;

    function mintBatchWithRoyalties(
        address receiver,
        uint256[] memory amounts,
        string[] memory newUris,
        uint96 _feeNumerator
    ) external;
}
