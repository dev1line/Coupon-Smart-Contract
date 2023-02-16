// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./lib/NFTHelper.sol";

enum NftStandard {
    ERC721,
    ERC1155,
    NONE
}

enum OrderStatus {
    PENDING,
    ACCEPTED,
    CANCELED
}

enum MarketItemStatus {
    LISTING,
    SOLD,
    CANCELED
}

/**
 *  @notice This struct defining data for each item selling on the marketplace
 *
 *  @param nftContractAddress           NFT Contract Address
 *  @param tokenId                      Token Id of NFT contract
 *  @param amount                       Amount if token is ERC1155
 *  @param price                        Price of this token
 *  @param nftType                      Type of this NFT
 *  @param seller                       The person who sell this NFT
 *  @param buyer                        The person who offer to this NFT
 *  @param status                       Status of this NFT at Marketplace
 *  @param startTime                    Time when the NFT push to Marketplace
 *  @param endTime                      Time when the NFT expire at Marketplace
 *  @param paymentToken                 Token to transfer
 */
struct MarketItem {
    address nftContractAddress;
    uint256 tokenId;
    uint256 amount;
    uint256 price;
    NFTHelper.Type nftType;
    address seller;
    address buyer;
    MarketItemStatus status;
    uint256 startTime;
    uint256 endTime;
    IERC20Upgradeable paymentToken;
    bytes signature;
}

/**
 *  @notice This struct defining data for general information of Order
 *
 *  @param nftAddress                               NFT Contract Address of this asset
 *  @param tokenId                                  Token Id of NFT contract
 *  @param amount                                   Amount to transfer
 *  @param bidPrice                                 Bid price
 *  @param expiredTime                              Expired time
 *  @param owner                                    owner address
 *  @param to                                       Seller
 *  @param paymentToken                             Token to transfer
 *  @param status                                   Status of order
 */
struct OrderInfo {
    uint256 id;
    address nftAddress;
    uint256 tokenId;
    uint256 amount;
    uint256 bidPrice;
    uint256 expiredTime;
    address owner;
    address to;
    IERC20Upgradeable paymentToken;
    OrderStatus status;
}

struct SigningInfo {
    address nftContractAddress;
    uint256 tokenId;
    uint256 amount;
    uint256 price;
    uint256 startTime;
    uint256 endTime;
    address paymentToken;
}
