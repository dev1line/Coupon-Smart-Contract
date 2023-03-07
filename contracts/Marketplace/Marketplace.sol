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
import "hardhat/console.sol";

/**
 *  @title  Dev Marketplace Contract
 *
 *  @author CMC Global Team
 *
 *  @notice This smart contract is the marketplace for exhange multiple non-fungiable token with standard ERC721 and ERC1155
 *          all action which user could sell, unsell, buy them.
 */
contract Marketplace is
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
    CountersUpgradeable.Counter private _orderIds;
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
     *  @notice Mapping from MarketItemID to Market Item
     *  @dev MarketItemID -> MarketItem
     */
    mapping(uint256 => MarketItem) public marketItemIdToMarketItem;

    /**
     *  @notice OrderId -> OrderInfo
     */
    mapping(uint256 => OrderInfo) public orders;

    /**
     *  @notice Mapping from NFT address => token ID => To => Owner ==> OrderInfo
     */
    mapping(address => mapping(uint256 => mapping(address => mapping(address => OrderInfo))))
        public orderOfOwners;

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
    event UpdateOrder(
        address owner,
        uint256 amount,
        uint256 bidPrice,
        uint256 expiredTime
    );
    event MakeOrder(
        uint256 indexed orderId,
        address owner,
        address to,
        address nftAddress,
        uint256 tokenId,
        uint256 amount,
        address paymentToken,
        uint256 bidPrice,
        uint256 expiredTime,
        OrderStatus status
    );
    event RoyaltiesPaid(uint256 indexed tokenId, uint256 indexed value);
    event AcceptedOrder(
        uint256 indexed orderId,
        address owner,
        address seller,
        uint256 amount,
        address paymentToken,
        address nftContractAddress,
        uint256 tokenId,
        uint256 bidPrice,
        bool isWallet
    );
    event CanceledOrder(uint256 indexed orderId);
    modifier validId(uint256 _id) {
        if (_id == 0 || _id > _marketItemIds.current()) {
            revert ErrorHelper.InvalidMarketItemId();
        }
        _;
    }

    modifier validOrderId(uint256 _id) {
        if (_id == 0 || _id > _orderIds.current()) {
            revert ErrorHelper.InvalidOrderId();
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
        listingFee = 0; // 2.5%
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    /**
     * @dev make Order with any NFT in wallet
     */
    function makeOrder(
        IERC20Upgradeable _paymentToken,
        uint256 _bidPrice,
        address _to,
        address _nftAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _time
    )
        external
        payable
        nonReentrant
        whenNotPaused
        validPaymentToken(_paymentToken)
        notZero(_bidPrice)
        validWallet(_to)
        notZero(_amount)
    {
        ErrorHelper._checkValidOrderTime(_time);
        ErrorHelper._checkUserCanOffer(_to);
        ErrorHelper._checkValidNFTAddress(_nftAddress);

        if (NFTHelper.isERC721(_nftAddress)) {
            ErrorHelper._checkValidOwnerOf721(_nftAddress, _tokenId, _to);
            ErrorHelper._checkValidAmountOf721(_amount);
        } else if (NFTHelper.isERC1155(_nftAddress)) {
            ErrorHelper._checkValidOwnerOf1155(
                _nftAddress,
                _tokenId,
                _to,
                _amount
            );
        }

        OrderInfo storage existOrder = orderOfOwners[_nftAddress][_tokenId][
            _to
        ][_msgSender()];

        if (
            existOrder.bidPrice != 0 && existOrder.status == OrderStatus.PENDING
        ) {
            ErrorHelper._checkCanUpdatePaymentToken(
                address(_paymentToken),
                address(existOrder.paymentToken)
            );
            _updateOrder(existOrder, _bidPrice, _amount, _time);
        } else {
            _orderIds.increment();

            OrderInfo memory orderInfo = OrderInfo({
                id: _orderIds.current(),
                nftAddress: _nftAddress,
                tokenId: _tokenId,
                amount: _amount,
                bidPrice: _bidPrice,
                expiredTime: _time,
                owner: _msgSender(),
                to: _to,
                paymentToken: _paymentToken,
                status: OrderStatus.PENDING
            });

            TransferHelper._transferToken(
                _paymentToken,
                _bidPrice,
                _msgSender(),
                address(this)
            );

            // Emit Event
            emit MakeOrder(
                _orderIds.current(),
                _msgSender(),
                orderInfo.to,
                orderInfo.nftAddress,
                orderInfo.tokenId,
                orderInfo.amount,
                address(orderInfo.paymentToken),
                orderInfo.bidPrice,
                orderInfo.expiredTime,
                orderInfo.status
            );
        }
    }

    function _updateOrder(
        OrderInfo storage existOrder,
        uint256 _bidPrice,
        uint256 _amount,
        uint256 _time
    ) internal {
        bool isExcess = _bidPrice < existOrder.bidPrice;
        uint256 excessAmount = isExcess
            ? existOrder.bidPrice - _bidPrice
            : _bidPrice - existOrder.bidPrice;

        // Update
        existOrder.bidPrice = _bidPrice;
        existOrder.amount = _amount;
        existOrder.expiredTime = _time;

        // Transfer
        if (excessAmount > 0) {
            if (!isExcess) {
                TransferHelper._transferToken(
                    existOrder.paymentToken,
                    excessAmount,
                    existOrder.owner,
                    address(this)
                );
            } else {
                TransferHelper._transferToken(
                    existOrder.paymentToken,
                    excessAmount,
                    address(this),
                    existOrder.owner
                );
            }
        }

        // Emit Event
        emit UpdateOrder(
            existOrder.owner,
            existOrder.amount,
            existOrder.bidPrice,
            existOrder.expiredTime
        );
    }

    /**
     *  @notice Accept Order
     *
     * * Emit {acceptOrder}
     */
    function acceptOrder(
        uint256 _orderId,
        uint256 _bidPrice
    ) external nonReentrant whenNotPaused validOrderId(_orderId) {
        OrderInfo memory orderInfo = orders[_orderId];

        ErrorHelper._checkIsSeller(orderInfo.to);

        ErrorHelper._checkInOrderTime(orderInfo.expiredTime);
        ErrorHelper._checkAvailableOrder(
            uint256(orderInfo.status),
            uint256(OrderStatus.PENDING)
        );
        ErrorHelper._checkEqualPrice(_bidPrice, orderInfo.bidPrice);

        // Update Order
        orderInfo.status = OrderStatus.ACCEPTED;
        isBuyer[orderInfo.owner] = true;

        // pay listing fee
        uint256 netSaleValue = _bidPrice - getListingFee(_bidPrice);
        // Pay royalties from the amount actually received
        netSaleValue = _deduceRoyalties(
            orderInfo.nftAddress,
            orderInfo.tokenId,
            netSaleValue,
            orderInfo.paymentToken
        );

        // Transfer Token from Buyer to Seller
        TransferHelper._transferToken(
            orderInfo.paymentToken,
            netSaleValue,
            address(this),
            orderInfo.owner
        );

        TransferHelper._transferToken(
            orderInfo.paymentToken,
            getListingFee(_bidPrice),
            address(this),
            admin.treasury()
        );

        NFTHelper.transferNFTCall(
            orderInfo.nftAddress,
            orderInfo.tokenId,
            orderInfo.amount,
            address(orderInfo.paymentToken),
            orderInfo.owner
        );
    }

    function cancelOrder(uint256 orderId) internal {
        OrderInfo storage orderInfo = orders[orderId];

        ErrorHelper._checkOwnerOfOrder(orderInfo.owner);
        ErrorHelper._checkAvailableOrder(
            uint256(orderInfo.status),
            uint256(OrderStatus.PENDING)
        );
        // Update order information
        orderInfo.status = OrderStatus.CANCELED;

        // Payback token to owner
        TransferHelper._transferToken(
            orderInfo.paymentToken,
            orderInfo.bidPrice,
            address(this),
            orderInfo.owner
        );

        emit CanceledOrder(orderId);
    }

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
            _msgSender(),
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
            _msgSender(),
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
        console.log(
            "seller",
            marketItem.seller,
            recover(signInfo, marketItem.signature)
        );
        require(
            marketItem.seller == recover(signInfo, marketItem.signature),
            "Wrong signature."
        );

        // deduct

        // TransferHelper._transferToken(
        //     IERC20Upgradeable(signInfo.paymentToken),
        //     getListingFee(signInfo.price),
        //     _msgSender(),
        //     treasury
        // );

        // TransferHelper._transferToken(
        //     IERC20Upgradeable(signInfo.paymentToken),
        //     signInfo.price,
        //     _msgSender(),
        //     marketItem.seller
        // );
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

    function getMessageHash(
        address nftContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        uint256 startTime,
        int256 endTime,
        address paymentToken
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "SigningInfo(address nftContractAddress, uint256 tokenId, uint256 amount, uint256 price, uint256 startTime, int256 endTime, address paymentToken)"
                        ),
                        nftContractAddress,
                        tokenId,
                        amount,
                        price,
                        startTime,
                        endTime,
                        paymentToken
                    )
                )
            );
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

    /**
     *  @notice Transfers royalties to the rightsowner if applicable and return the remaining amount
     *  @param nftContractAddress  address contract of nft
     *  @param tokenId  token id of nft
     *  @param grossSaleValue  price of nft that is listed
     *  @param paymentToken  token for payment
     */
    function _deduceRoyalties(
        address nftContractAddress,
        uint256 tokenId,
        uint256 grossSaleValue,
        IERC20Upgradeable paymentToken
    ) internal returns (uint256 netSaleAmount) {
        // Get amount of royalties to pays and recipient
        if (NFTHelper.isRoyalty(nftContractAddress)) {
            (
                address royaltiesReceiver,
                uint256 royaltiesAmount
            ) = _getRoyaltyInfo(nftContractAddress, tokenId, grossSaleValue);

            // Deduce royalties from sale value
            uint256 netSaleValue = grossSaleValue - royaltiesAmount;
            // Transfer royalties to rightholder if not zero
            if (royaltiesAmount > 0) {
                TransferHelper._transferToken(
                    paymentToken,
                    royaltiesAmount,
                    address(this),
                    royaltiesReceiver
                );
                // Broadcast royalties payment
                emit RoyaltiesPaid(tokenId, royaltiesAmount);
            }

            return netSaleValue;
        }
        return grossSaleValue;
    }

    function _getRoyaltyInfo(
        address _nftAddr,
        uint256 _tokenId,
        uint256 _salePrice
    ) internal view returns (address, uint256) {
        (
            address royaltiesReceiver,
            uint256 royaltiesAmount
        ) = IERC2981Upgradeable(_nftAddr).royaltyInfo(_tokenId, _salePrice);
        return (royaltiesReceiver, royaltiesAmount);
    }
}
