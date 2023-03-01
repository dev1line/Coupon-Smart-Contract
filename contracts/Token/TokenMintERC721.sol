// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";

import "../interfaces/ITokenMintERC721.sol";
import "../Validatable.sol";
import "../lib/ErrorHelper.sol";

/**
 *  @title  Dev Non-fungible token
 *
 *  @author CMC Global Team
 *
 *  @notice This smart contract create the token ERC721 for Operation. These tokens initially are minted
 *          by the all user and using for purchase in marketplace operation.
 *          The contract here by is implemented to initial some NFT with royalties.
 */
contract TokenMintERC721 is
    Validatable,
    ERC721EnumerableUpgradeable,
    ERC2981Upgradeable,
    ITokenMintERC721
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /**
     *  @notice _tokenCounter uint256 (counter). This is the counter for store
     *          current token ID value in storage.
     */
    CountersUpgradeable.Counter private _tokenCounter;

    /**
     *  @notice uris mapping from token ID to token uri
     */
    mapping(uint256 => string) public uris;

    event Minted(uint256 indexed tokenId, address indexed to);
    event MintedBatch(uint256[] tokenIds, address indexed to);
    event MintedWithRoyalties(uint256 indexed tokenId, address indexed to);
    event MintedBatchWithRoyalties(uint256[] tokenIds, address indexed to);

    /**
     *  @notice Initialize new logic contract.
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        IAdmin _admin
    ) public initializer {
        __Validatable_init(_admin);
        __ERC721_init(_name, _symbol);

        admin = _admin;
    }

    /**
     *  @notice Mint NFT not pay token
     *
     *  @dev    Only owner or admin can call this function.
     */
    function mint(
        address receiver,
        string memory uri
    ) external onlyAdmin notZeroAddress(receiver) {
        _tokenCounter.increment();
        uint256 tokenId = _tokenCounter.current();

        uris[tokenId] = uri;

        _mint(receiver, tokenId);

        emit Minted(tokenId, receiver);
    }

    /**
     *  @notice Mint Batch NFT not pay token
     *
     *  @dev    Only owner or admin can call this function.
     *  @dev    Max mint 100 tokens
     */
    function mintBatch(
        address receiver,
        string[] memory newUris
    ) external onlyAdmin notZeroAddress(receiver) {
        ErrorHelper._checkExceed(100, newUris.length);
        uint256[] memory tokenIds = new uint256[](newUris.length);
        for (uint256 i = 0; i < newUris.length; ++i) {
            _tokenCounter.increment();
            uint256 tokenId = _tokenCounter.current();

            uris[tokenId] = newUris[i];
            tokenIds[i] = tokenId;

            _mint(receiver, tokenId);
        }

        emit MintedBatch(tokenIds, receiver);
    }

    /**
     *  @notice Mint NFT not pay token with royalty
     *
     *  @dev    Only owner or admin can call this function.
     */
    function mintWithRoyalties(
        address receiver,
        string memory uri,
        uint96 _feeNumerator
    ) external onlyAdmin notZeroAddress(receiver) {
        _tokenCounter.increment();
        uint256 tokenId = _tokenCounter.current();

        uris[tokenId] = uri;

        _setTokenRoyalty(tokenId, receiver, _feeNumerator);

        _mint(receiver, tokenId);

        emit MintedWithRoyalties(tokenId, receiver);
    }

    /**
     *  @notice Mint Batch NFT not pay token with royalty
     *
     *  @dev    Only owner or admin can call this function.
     *  @dev    Max mint 100 tokens
     */
    function mintBatchWithRoyalties(
        address receiver,
        string[] memory newUris,
        uint96 _feeNumerator
    ) external onlyAdmin notZeroAddress(receiver) {
        ErrorHelper._checkExceed(100, newUris.length);
        uint256[] memory tokenIds = new uint256[](newUris.length);
        for (uint256 i = 0; i < newUris.length; ++i) {
            _tokenCounter.increment();
            uint256 tokenId = _tokenCounter.current();

            uris[tokenId] = newUris[i];
            tokenIds[i] = tokenId;

            _setTokenRoyalty(tokenId, receiver, _feeNumerator);

            _mint(receiver, tokenId);
        }

        emit MintedBatchWithRoyalties(tokenIds, receiver);
    }

    /**
     *  @notice Set new uri for each token ID
     */
    function setTokenURI(
        string memory newURI,
        uint256 tokenId
    ) external onlyAdmin {
        uris[tokenId] = newURI;
    }

    /**
     *  @notice Get token counter
     *
     *  @dev    All caller can call this function.
     */
    function getTokenCounter() external view returns (uint256) {
        return _tokenCounter.current();
    }

    // /**
    //  *  @notice Get list token ID of owner address.
    //  */
    // function tokensOfOwner(
    //     address owner
    // ) public view returns (uint256[] memory) {
    //     uint256 count = balanceOf(owner);
    //     uint256[] memory ids = new uint256[](count);
    //     for (uint256 i = 0; i < count; i++) {
    //         ids[i] = tokenOfOwnerByIndex(owner, i);
    //     }
    //     return ids;
    // }

    /**
     *  @notice Mapping token ID to base URI in ipfs storage
     *
     *  @dev    All caller can call this function.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        if (!_exists(tokenId)) {
            revert ErrorHelper.URIQueryNonExistToken();
        }
        return uris[tokenId];
    }

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(
            ERC721EnumerableUpgradeable,
            IERC165Upgradeable,
            ERC2981Upgradeable
        )
        returns (bool)
    {
        return
            interfaceId == type(ITokenMintERC721).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
