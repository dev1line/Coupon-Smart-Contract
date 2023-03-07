// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../lib/NFTHelper.sol";
import "../Validatable.sol";
import "../interfaces/INFTManager.sol";
import "../interfaces/ITokenMintERC721.sol";
import "../interfaces/ITokenMintERC1155.sol";
import "../interfaces/Collection/ITokenERC721.sol";
import "../interfaces/Collection/ITokenERC1155.sol";
import "../lib/ErrorHelper.sol";

/**
 *  @title  Dev NFT Management Contract
 *
 *  @author CMC Global Team
 *
 *  @notice This smart contract create the token NFT manager for Operation. These contract using to control
 *          all action which user call and interact for purchasing in marketplace operation.
 */
contract NFTManager is
    Validatable,
    ReentrancyGuardUpgradeable,
    ERC165Upgradeable,
    INFTManager
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     *  @notice tokenMintERC721 is interface of tokenMint ERC721
     */
    ITokenMintERC721 public tokenMintERC721;

    /**
     *  @notice tokenMintERC1155 is interface of tokenMint ERC1155
     */
    ITokenMintERC1155 public tokenMintERC1155;

    event Created(
        address indexed nftAddress,
        uint256 tokenId,
        address owner,
        uint256 amount
    );
    event BatchCreated(
        address indexed nftAddress,
        uint256 tokenId,
        address owner,
        uint256[] amount
    );

    event BatchCreatedWithRoyalties(
        address indexed nftAddress,
        uint256 tokenId,
        address owner,
        uint256[] amount,
        uint96 fee
    );

    /**
     *  @notice Initialize new logic contract.
     */
    function initialize(
        ITokenMintERC721 nft721Addr,
        ITokenMintERC1155 nft1155Addr,
        IAdmin _admin
    ) public initializer {
        __Validatable_init(_admin);
        __ReentrancyGuard_init();
        __ERC165_init();

        tokenMintERC721 = nft721Addr;
        tokenMintERC1155 = nft1155Addr;
    }

    /**
     *  @notice Create NFT
     *
     *  @dev    All caller can call this function.
     */
    function createNFT(
        NFTHelper.Type typeNft,
        uint256 amount,
        string memory uri
    ) external whenNotPaused nonReentrant notZero(amount) {
        uint256 currentId;
        if (typeNft == NFTHelper.Type.ERC721) {
            ITokenMintERC721(address(tokenMintERC721)).mint(_msgSender(), uri);
            currentId = ITokenMintERC721(address(tokenMintERC721))
                .getTokenCounter();
        } else {
            ITokenMintERC1155(address(tokenMintERC1155)).mint(
                _msgSender(),
                amount,
                uri
            );
            currentId = ITokenMintERC1155(address(tokenMintERC1155))
                .getTokenCounter();
        }
        emit Created(
            typeNft == NFTHelper.Type.ERC721
                ? address(tokenMintERC721)
                : address(tokenMintERC1155),
            currentId,
            _msgSender(),
            amount
        );
    }

    /**
     *  @notice Create batch NFT
     *
     *  @dev    All caller can call this function.
     */
    function createBatchNFT(
        NFTHelper.Type typeNft,
        uint256[] memory amounts,
        string[] memory newUris
    ) external whenNotPaused nonReentrant {
        uint256 currentId;
        if (typeNft == NFTHelper.Type.ERC721) {
            ITokenMintERC721(address(tokenMintERC721)).mintBatch(
                _msgSender(),
                newUris
            );
            currentId = ITokenMintERC721(address(tokenMintERC721))
                .getTokenCounter();
        } else {
            ITokenMintERC1155(address(tokenMintERC1155)).mintBatch(
                _msgSender(),
                amounts,
                newUris
            );
            currentId = ITokenMintERC1155(address(tokenMintERC1155))
                .getTokenCounter();
        }

        emit BatchCreated(
            typeNft == NFTHelper.Type.ERC721
                ? address(tokenMintERC721)
                : address(tokenMintERC1155),
            currentId,
            _msgSender(),
            amounts
        );
    }

    /**
     *  @notice Create batch NFT with royalties
     *
     *  @dev    All caller can call this function.
     */
    function createBatchNFTWithRoyalties(
        NFTHelper.Type typeNft,
        uint256[] memory amounts,
        string[] memory newUris,
        uint96 _feeNumerator
    ) external whenNotPaused nonReentrant {
        uint256 currentId;
        if (typeNft == NFTHelper.Type.ERC721) {
            ITokenMintERC721(address(tokenMintERC721)).mintBatchWithRoyalties(
                _msgSender(),
                newUris,
                _feeNumerator
            );
            currentId = ITokenMintERC721(address(tokenMintERC721))
                .getTokenCounter();
        } else {
            ITokenMintERC1155(address(tokenMintERC1155)).mintBatchWithRoyalties(
                    _msgSender(),
                    amounts,
                    newUris,
                    _feeNumerator
                );
            currentId = ITokenMintERC1155(address(tokenMintERC1155))
                .getTokenCounter();
        }
        emit BatchCreatedWithRoyalties(
            typeNft == NFTHelper.Type.ERC721
                ? address(tokenMintERC721)
                : address(tokenMintERC1155),
            currentId,
            _msgSender(),
            amounts,
            _feeNumerator
        );
    }

    // /**
    //  *  @notice Create NFT From Collection
    //  *
    //  *  @dev    All caller can call this function.
    //  */
    // function createNFTFromCollection(
    //     address nftAddress,
    //     uint256 amount,
    //     string memory uri
    // ) external whenNotPaused nonReentrant notZero(amount) {
    //     ErrorHelper._checkValidNFTAddress(nftAddress);
    //     NFTHelper.Type typeNft = NFTHelper.getType(nftAddress);
    //     uint256 currentId;
    //     if (typeNft == NFTHelper.Type.ERC721) {
    //         ITokenERC721(nftAddress).mint(_msgSender(), uri);
    //         currentId = ITokenERC721(nftAddress).getTokenCounter();
    //     } else if (typeNft == NFTHelper.Type.ERC1155) {
    //         ITokenERC1155(nftAddress).mint(_msgSender(), amount, uri);
    //         currentId = ITokenERC1155(nftAddress).getTokenCounter();
    //     }
    //     emit Created(nftAddress, currentId, _msgSender(), amount);
    // }

    // /**
    //  *  @notice Create Batch NFT From Collection
    //  *
    //  *  @dev    All caller can call this function.
    //  */
    // function createBatchNFTFromCollection(
    //     address nftAddress,
    //     uint256[] memory amounts,
    //     string[] memory newUris
    // ) external whenNotPaused nonReentrant {
    //     ErrorHelper._checkValidNFTAddress(nftAddress);
    //     NFTHelper.Type typeNft = NFTHelper.getType(nftAddress);
    //     uint256 currentId;
    //     if (typeNft == NFTHelper.Type.ERC721) {
    //         ITokenERC721(nftAddress).mintBatchWithUri(_msgSender(), newUris);
    //         currentId = ITokenERC721(nftAddress).getTokenCounter();
    //     } else if (typeNft == NFTHelper.Type.ERC1155) {
    //         ITokenERC1155(nftAddress).mintBatch(_msgSender(), amounts, newUris);
    //         currentId = ITokenERC1155(nftAddress).getTokenCounter();
    //     }
    //     emit BatchCreated(nftAddress, currentId, _msgSender(), amounts);
    // }
}
