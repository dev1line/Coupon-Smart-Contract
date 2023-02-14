// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "../interfaces/IMarketplace.sol";
import "../Struct.sol";
import "../Validatable.sol";

/**
 *  @title  Dev Marketplace Contract
 *
 *  @author CMC Global Team
 *
 *  @notice This smart contract is the marketplace for exhange multiple non-fungiable token with standard ERC721 and ERC1155
 *          all action which user could sell, unsell, buy them.
 */
contract MarketPlaceManager is
    Validatable,
    ReentrancyGuardUpgradeable,
    ERC721HolderUpgradeable,
    ERC1155HolderUpgradeable,
    EIP712Upgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using AddressUpgradeable for address;

    string private constant SIGNING_DOMAIN = "CMCG-Signing-Domain";
    string private constant SIGNATURE_VERSION = "1";

    CountersUpgradeable.Counter private _marketItemIds;

    uint256 public constant DENOMINATOR = 1e5;

    /**
     *  @notice listingFee is fee user must pay for contract when create
     */
    uint256 public listingFee;

    /**
     *  @notice treasury is address of Treasury
     */
    address public treasury;

    /**
     *  @notice isBuyer is mapping owner address to account was buyer in marketplace
     */
    mapping(address => bool) public isBuyer;

    /**
     *  @notice nftAddressToRootHash is mapping nft address to root hash
     */
    mapping(address => bytes32) public nftAddressToRootHash;

    /**
     *  @notice Mapping from MarketItemID to Market Item
     *  @dev MarketItemID -> MarketItem
     */
    mapping(uint256 => MarketItem) public marketItemIdToMarketItem;

    event Sold(
        uint256 indexed marketItemId,
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        address indexed seller,
        uint256 price,
        uint256 nftType,
        uint256 startTime,
        uint256 endTime,
        IERC20Upgradeable paymentToken
    );
    event CanceledSell(uint256 indexed marketItemId);
    event Bought(
        uint256 indexed marketItemId,
        address nftContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        address buyer,
        MarketItemStatus status
    );
    event ReSold(
        uint256 indexed marketItemId,
        uint256 price,
        uint256 startTime,
        uint256 endTime
    );
    modifier validId(uint256 _id) {
        if (_id == 0 || _id > _marketItemIds.current()) {
            revert ErrorHelper.InvalidMarketItemId();
        }
        _;
    }

    /**
     *  @notice Initialize new logic contract.
     */
    function initialize(IAdmin _admin) public initializer {
        __Validatable_init(_admin);
        __ReentrancyGuard_init();
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
        treasury = _admin.treasury();
        listingFee = 25e2; // 2.5%
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    /**
     *  @notice Create market info with data
     *
     *  @dev    All caller can call this function.
     */
    function sell(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        address _seller,
        uint256 _startTime,
        uint256 _endTime,
        IERC20Upgradeable _paymentToken,
        bytes calldata _signature
    ) external validPaymentToken(_paymentToken) {
        ErrorHelper._checkExistToken(_nftAddress, _tokenId);

        NFTHelper.Type nftType = NFTHelper.getType(_nftAddress);
        if (nftType == NFTHelper.Type.ERC721) {
            ErrorHelper._checkValidAmountOf721(_amount);
        }
        ErrorHelper._checkValidTimeForCreate(_startTime, _endTime);

        _marketItemIds.increment();

        marketItemIdToMarketItem[_marketItemIds.current()] = MarketItem(
            _nftAddress,
            _tokenId,
            _amount,
            _price,
            nftType,
            _seller,
            address(0),
            MarketItemStatus.LISTING,
            _startTime,
            _endTime,
            _paymentToken,
            _signature
        );

        emit Sold(
            _marketItemIds.current(),
            _nftAddress,
            _tokenId,
            _amount,
            _seller,
            _price,
            uint256(nftType),
            _startTime,
            _endTime,
            _paymentToken
        );
    }

    /**
     *  @notice Resell Market Item avaiable in marketplace after Market Item is expired
     *
     *  Emit {SoldAvailableItem}
     */
    function resell(
        uint256 marketItemId,
        uint256 price,
        uint256 startTime,
        uint256 endTime
    ) external nonReentrant whenNotPaused validId(marketItemId) notZero(price) {
        MarketItem storage marketItem = marketItemIdToMarketItem[marketItemId];

        ErrorHelper._checkValidMarketItem(
            uint256(marketItem.status),
            uint256(MarketItemStatus.LISTING)
        );
        ErrorHelper._checkIsSeller(marketItem.seller);
        ErrorHelper._checkExpired(marketItem.endTime);
        ErrorHelper._checkValidEndTime(endTime);

        marketItem.price = price;
        marketItem.startTime = startTime;
        marketItem.endTime = endTime;

        emit ReSold(
            marketItemId,
            marketItem.price,
            marketItem.startTime,
            marketItem.endTime
        );
    }

    /**
     *  @notice Canncel any nft which selling
     *
     *  @dev    All caller can call this function.
     *
     *  Emit {CanceledSell}
     */
    function cancelSell(
        uint256 marketItemId
    ) external payable nonReentrant whenNotPaused validId(marketItemId) {
        MarketItem storage marketItem = marketItemIdToMarketItem[marketItemId];
        ErrorHelper._checkValidMarketItem(
            uint256(marketItem.status),
            uint256(MarketItemStatus.LISTING)
        );
        ErrorHelper._checkIsSeller(marketItem.seller);

        marketItem.status = MarketItemStatus.CANCELED;

        TransferHelper._transferToken(
            IERC20Upgradeable(marketItem.paymentToken),
            getListingFee(marketItem.price),
            _msgSender(),
            treasury
        );

        emit CanceledSell(marketItemId);
    }

    function buy(
        uint256 marketItemId
    ) external payable nonReentrant whenNotPaused validId(marketItemId) {
        MarketItem storage marketItem = marketItemIdToMarketItem[marketItemId];
        ErrorHelper._checkValidMarketItem(
            uint256(marketItem.status),
            uint256(MarketItemStatus.LISTING)
        );
        ErrorHelper._checkOwnerOfMarketItem(marketItem.seller);
        ErrorHelper._checkMarketItemInSelling(
            marketItem.startTime,
            marketItem.endTime
        );

        SigningInfo memory signInfo = SigningInfo({
            nftContractAddress: marketItem.nftContractAddress,
            tokenId: marketItem.tokenId,
            amount: marketItem.amount,
            price: marketItem.price,
            startTime: marketItem.startTime,
            endTime: marketItem.startTime,
            paymentToken: address(marketItem.paymentToken)
        });

        require(
            marketItem.seller == recover(signInfo, marketItem.signature),
            "Wrong signature."
        );

        TransferHelper._transferToken(
            IERC20Upgradeable(signInfo.paymentToken),
            signInfo.price,
            _msgSender(),
            treasury
        );

        TransferHelper._transferToken(
            IERC20Upgradeable(signInfo.paymentToken),
            signInfo.price - getListingFee(signInfo.price),
            treasury,
            marketItem.seller
        );
        NFTHelper.transferNFTCall(
            signInfo.nftContractAddress,
            signInfo.tokenId,
            signInfo.amount,
            marketItem.seller,
            _msgSender()
        );

        emit Bought(
            marketItemId,
            signInfo.nftContractAddress,
            signInfo.tokenId,
            signInfo.amount,
            signInfo.price,
            marketItem.buyer,
            marketItem.status
        );
    }

    /**
     *  @notice Fetch information Market Item by Market ID
     *
     *  @dev    All caller can call this function.
     */
    function fetchMarketItemsByMarketID(
        uint256 marketId
    ) external view returns (MarketItem memory) {
        return marketItemIdToMarketItem[marketId];
    }

    /**
     *  @notice Get current market item id
     *
     *  @dev    All caller can call this function.
     */
    function getCurrentMarketItem() external view returns (uint256) {
        return _marketItemIds.current();
    }

    /**
     *  @notice Check account bought or not to check in staking pool
     */
    function wasBuyer(address account) external view returns (bool) {
        return isBuyer[account];
    }

    /**
     *  @notice check and get Royalties information
     *
     *  @dev    All caller can call this function.
     */
    function getRoyaltyInfo(
        address _nftAddr,
        uint256 _tokenId,
        uint256 _salePrice
    ) public view returns (address, uint256) {
        (
            address royaltiesReceiver,
            uint256 royaltiesAmount
        ) = IERC2981Upgradeable(_nftAddr).royaltyInfo(_tokenId, _salePrice);
        return (royaltiesReceiver, royaltiesAmount);
    }

    /**
     *  @notice Return permit token payment
     */
    function isPermittedPaymentToken(
        IERC20Upgradeable token
    ) public view returns (bool) {
        return admin.isPermittedPaymentToken(token);
    }

    /**
     *  @notice get Listing fee
     *
     *  @dev    All caller can call this function.
     */
    function getListingFee(uint256 amount) public view returns (uint256) {
        return (amount * listingFee) / DENOMINATOR;
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
    ) public view virtual override(ERC1155ReceiverUpgradeable) returns (bool) {
        return
            interfaceId == type(IMarketplace).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function recover(
        SigningInfo memory signing,
        bytes memory signature
    ) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "SigningInfo(address nftContractAddress, uint256 tokenId, uint256 amount, uint256 price, uint256 startTime, int256 endTime, address paymentToken)"
                    ),
                    signing.nftContractAddress,
                    signing.tokenId,
                    signing.amount,
                    signing.price,
                    signing.startTime,
                    signing.endTime,
                    signing.paymentToken
                )
            )
        );
        address signer = ECDSAUpgradeable.recover(digest, signature);
        return signer;
    }

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * @dev See {IERC1155Receiver-onERC1155Received}.
     *
     * Always returns `IERC1155Receiver.onERC1155Received.selector`.
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function isRoyalty(address _contract) external view returns (bool) {
        return NFTHelper.isRoyalty(_contract);
    }

    /**
     *  @notice get market item info from market item ID
     */
    function getMarketItemIdToMarketItem(
        uint256 marketItemId
    ) external view returns (MarketItem memory) {
        return marketItemIdToMarketItem[marketItemId];
    }

    /**
     *  @notice Check standard
     */
    function checkStandard(address _contract) public view returns (uint256) {
        if (
            IERC721Upgradeable(_contract).supportsInterface(
                type(IERC721Upgradeable).interfaceId
            )
        ) {
            return uint256(NftStandard.ERC721);
        }
        if (
            IERC1155Upgradeable(_contract).supportsInterface(
                type(IERC1155Upgradeable).interfaceId
            )
        ) {
            return uint256(NftStandard.ERC1155);
        }
        return uint256(NftStandard.NONE);
    }
}
