// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "../interfaces/Auction/IAuctionFactory.sol";
import "../interfaces/Auction/IDutchAuction.sol";
import "../interfaces/Auction/IEnglishAuction.sol";

import "../Validatable.sol";

contract AuctionFactory is IAuctionFactory, Validatable, ERC165Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    IDutchAuction public dutchTemplate;
    IEnglishAuction public englishTemplate;

    CountersUpgradeable.Counter private _auctionCounter;

    enum AuctionType {
        DUTCH,
        ENGLISH
    }
    /**
     *  @notice This struct defining data for each item auction
     *
     *  @param AucType                      Type of Auction
     *  @param salt                         Additional data to make the Auction unique
     *  @param auctionAddress               Address of the Auction
     *  @param owner                        Owner's Address of the Auction
     */
    struct AuctionInfo {
        AuctionType AucType;
        bytes32 salt;
        address auctionAddress;
        address owner;
    }

    mapping(uint256 => AuctionInfo) public auctionIdToAuctionInfo;
    mapping(address => EnumerableSetUpgradeable.AddressSet)
        private _ownerToAuction;

    event AuctionDeployed(
        AuctionType aucType,
        address auction,
        address deployer
    );

    event SetDutchAuctionTemplate(
        address indexed oldDutch,
        address indexed newDutch
    );
    event SetEnglishAuctionTemplate(
        address indexed oldEnglish,
        address indexed newEnglish
    );

    function initialize(
        IDutchAuction _dutchTemplate,
        IEnglishAuction _englishTemplate,
        IAdmin _admin
    ) public initializer {
        __ERC165_init();
        __Validatable_init(_admin);

        dutchTemplate = _dutchTemplate;
        englishTemplate = _englishTemplate;
    }

    function create(
        AuctionType aucType,
        IERC721Upgradeable _nft,
        uint256 _tokenId,
        IERC20Upgradeable _paymentToken,
        uint256 _startingBid,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _discountRate
    ) external whenNotPaused {
        _auctionCounter.increment();
        uint256 _currentId = _auctionCounter.current();
        bytes32 salt = bytes32(_currentId);
        address _auction;
        if (aucType == AuctionType.DUTCH) {
            IDutchAuction _dutchAuc = IDutchAuction(
                ClonesUpgradeable.cloneDeterministic(
                    address(dutchTemplate),
                    salt
                )
            );
            _auction = address(_dutchAuc);
        } else {
            IEnglishAuction _engAuc = IEnglishAuction(
                ClonesUpgradeable.cloneDeterministic(
                    address(englishTemplate),
                    salt
                )
            );
            _auction = address(_engAuc);
        }

        ErrorHelper._checkCloneAuction(_auction);
        // store
        AuctionInfo memory newInfo = AuctionInfo(
            aucType,
            salt,
            _auction,
            admin.owner()
        );
        auctionIdToAuctionInfo[_currentId] = newInfo;

        // initialize
        if (aucType == AuctionType.DUTCH) {
            IDutchAuction(_auction).initialize(
                _msgSender(),
                _nft,
                _tokenId,
                _paymentToken,
                _startingBid,
                _startTime,
                _endTime,
                _discountRate
            );
        } else {
            IEnglishAuction(_auction).initialize(
                _msgSender(),
                _nft,
                _tokenId,
                _paymentToken,
                _startingBid,
                _startTime,
                _endTime
            );
        }

        _ownerToAuction[_msgSender()].add(_auction);

        // transfer NFT into auction contract
        NFTHelper.transferNFTCall(
            address(_nft),
            _tokenId,
            0,
            _msgSender(),
            address(_auction)
        );

        emit AuctionDeployed(aucType, _auction, _msgSender());
    }

    /**
     *  @notice Set template dddress
     *  @param  _dutchTemplate that set dutch address
     */
    function setDutchTemplate(
        address _dutchTemplate
    ) external notZeroAddress(_dutchTemplate) onlyAdmin {
        IDutchAuction old = dutchTemplate;
        dutchTemplate = IDutchAuction(_dutchTemplate);

        emit SetDutchAuctionTemplate(address(old), address(dutchTemplate));
    }

    /**
     *  @notice Set template dddress
     *  @param  _englishTemplate that set english address
     */
    function setEnglishAuction(
        address _englishTemplate
    ) external notZeroAddress(_englishTemplate) onlyAdmin {
        IEnglishAuction old = englishTemplate;
        englishTemplate = IEnglishAuction(_englishTemplate);

        emit SetEnglishAuctionTemplate(address(old), address(englishTemplate));
    }

    // /**
    //  * @dev Returns true if this contract implements the interface defined by
    //  * `interfaceId`. See the corresponding
    //  * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
    //  * to learn more about how these ids are created.
    //  *
    //  * This function call must use less than 30 000 gas.
    //  */
    // function supportsInterface(
    //     bytes4 interfaceId
    // )
    //     public
    //     view
    //     virtual
    //     override(ERC165Upgradeable, IERC165Upgradeable)
    //     returns (bool)
    // {
    //     return
    //         interfaceId == type(IAuctionFactory).interfaceId ||
    //         super.supportsInterface(interfaceId);
    // }

    function checkAuctionOfUser(
        address _user,
        address _auction
    ) external view returns (bool) {
        return _ownerToAuction[_user].contains(_auction);
    }

    function getAuctionByUser(
        address _user
    ) external view returns (address[] memory) {
        return _ownerToAuction[_user].values();
    }

    function getAuctionId() public view returns (uint256) {
        return _auctionCounter.current();
    }
}
