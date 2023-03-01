// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IDutchAuction is IERC165Upgradeable {
    function initialize(
        address _owner,
        IERC721Upgradeable _nft,
        uint256 _tokenId,
        IERC20Upgradeable _paymentToken,
        uint256 _startingBid,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _discountRate
    ) external;
}
