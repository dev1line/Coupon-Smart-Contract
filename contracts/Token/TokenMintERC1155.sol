// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";

import "../interfaces/ITokenMintERC1155.sol";
import "../Validatable.sol";
import "../lib/ErrorHelper.sol";

/**
 *  @title  Dev Non-fungible token
 *
 *  @author CMC Global Team
 *
 *  @notice This smart contract create the token ERC1155 for Operation. These tokens initially are minted
 *          by the all user and using for purchase in marketplace operation.
 *          The contract here by is implemented to initial some NFT with royalties.
 */

contract TokenMintERC1155 is
    Validatable,
    ERC1155Upgradeable,
    ERC2981Upgradeable,
    ITokenMintERC1155
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
    function initialize(IAdmin _admin) public initializer {
        __Validatable_init(_admin);
        __ERC1155_init("");
    }

    /**
     *  @notice Set new uri for each token ID
     */
    function setURI(string memory newuri, uint256 tokenId) external onlyAdmin {
        uris[tokenId] = newuri;
    }

    /**
     *  @notice Mint NFT not pay token
     *
     *  @dev    Only owner or admin can call this function.
     */
    function mint(
        address receiver,
        uint256 amount,
        string memory newuri
    ) external onlyAdmin notZeroAddress(receiver) notZero(amount) {
        _tokenCounter.increment();
        uint256 tokenId = _tokenCounter.current();

        uris[tokenId] = newuri;

        _mint(receiver, tokenId, amount, "");

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
        uint256[] memory amounts,
        string[] memory newUris
    ) external onlyAdmin notZeroAddress(receiver) {
        ErrorHelper._checkEqualLength(newUris.length, amounts.length);
        ErrorHelper._checkExceed(100, newUris.length);
        uint256[] memory tokenIds = new uint256[](newUris.length);
        for (uint256 i = 0; i < newUris.length; ++i) {
            uint256 amount = amounts[i];

            ErrorHelper._checkValidAmount(amount);
            _tokenCounter.increment();
            uint256 tokenId = _tokenCounter.current();

            uris[tokenId] = newUris[i];
            tokenIds[i] = tokenId;

            _mint(receiver, tokenId, amount, "");
        }

        emit MintedBatch(tokenIds, receiver);
    }

    /**
     *  @notice Mint NFT not pay token
     *
     *  @dev    Only owner or admin can call this function.
     */
    function mintithRoyalties(
        address receiver,
        uint256 amount,
        string memory newuri,
        uint96 _feeNumerator
    ) external onlyAdmin notZeroAddress(receiver) notZero(amount) {
        _tokenCounter.increment();
        uint256 tokenId = _tokenCounter.current();

        uris[tokenId] = newuri;

        _setTokenRoyalty(tokenId, receiver, _feeNumerator);

        _mint(receiver, tokenId, amount, "");

        emit MintedWithRoyalties(tokenId, receiver);
    }

    /**
     *  @notice Mint Batch NFT not pay token
     *
     *  @dev    Only owner or admin can call this function.
     *  @dev    Max mint 100 tokens
     */
    function mintBatchithRoyalties(
        address receiver,
        uint256[] memory amounts,
        string[] memory newUris,
        uint96 _feeNumerator
    ) external onlyAdmin notZeroAddress(receiver) {
        ErrorHelper._checkEqualLength(newUris.length, amounts.length);
        ErrorHelper._checkExceed(100, newUris.length);
        uint256[] memory tokenIds = new uint256[](newUris.length);
        for (uint256 i = 0; i < newUris.length; ++i) {
            uint256 amount = amounts[i];

            ErrorHelper._checkValidAmount(amount);
            _tokenCounter.increment();
            uint256 tokenId = _tokenCounter.current();

            uris[tokenId] = newUris[i];
            tokenIds[i] = tokenId;

            _setTokenRoyalty(tokenId, receiver, _feeNumerator);

            _mint(receiver, tokenId, amount, "");
        }

        emit MintedBatchWithRoyalties(tokenIds, receiver);
    }

    /**
     *  @notice Get token counter
     *
     *  @dev    All caller can call this function.
     */
    function getTokenCounter() external view returns (uint256) {
        return _tokenCounter.current();
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
        override(ERC1155Upgradeable, IERC165Upgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(ITokenMintERC1155).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     *  @notice Return token URI.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        return uris[tokenId];
    }
}
