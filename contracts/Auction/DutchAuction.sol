// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "../lib/TransferHelper.sol";
import "../lib/NFTHelper.sol";

/**
 *  @title  Dev Dutch Auction
 *
 *  @author CMC Global Team
 *
 *  @notice This smart contract set up an dutch auction with a NFT ERC-721
 *          that is the reward for highest bidder in countdown
 */
contract DutchAuction is OwnableUpgradeable, ERC721HolderUpgradeable {
    IERC721Upgradeable public nftReward;
    uint256 public nftId;
    uint256 public startingPrice;
    uint256 public discountRate;
    IERC20Upgradeable public paymentToken;
    uint256 public startTime;
    uint256 public endTime;
    bool public isEnded;

    event Bought(address indexed winner, uint256 amount);

    function initialize(
        address _owner,
        IERC721Upgradeable _nft,
        uint256 _tokenId,
        IERC20Upgradeable _paymentToken,
        uint256 _startingBid,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _discountRate
    ) public initializer {
        OwnableUpgradeable.__Ownable_init();
        transferOwnership(_owner);
        startTime = _startTime;
        endTime = _endTime;
        nftReward = _nft;
        nftId = _tokenId;
        startingPrice = _startingBid;
        paymentToken = _paymentToken;
        discountRate = _discountRate;

        // // transfer NFT into auction contract
        // NFTHelper.transferNFTCall(
        //     address(_nft),
        //     _tokenId,
        //     0,
        //     _owner,
        //     address(this)
        // );
    }

    function getPrice() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - startTime;
        uint256 discount = discountRate * timeElapsed;
        return startingPrice - discount;
    }

    function withdraw() external onlyOwner {
        if (isEnded) {
            TransferHelper._transferToken(
                paymentToken,
                address(this).balance,
                address(this),
                _msgSender()
            );
        } else {
            nftReward.safeTransferFrom(address(this), _msgSender(), nftId);
        }
        isEnded = true;
    }

    function buy(uint256 amount) external payable {
        require(startTime <= block.timestamp, "not started");
        require(block.timestamp < endTime, "ended");
        require(amount >= getPrice(), "value < price");
        isEnded = true;

        TransferHelper._transferToken(
            paymentToken,
            amount,
            _msgSender(),
            address(this)
        );

        nftReward.safeTransferFrom(address(this), _msgSender(), nftId);

        TransferHelper._transferToken(
            paymentToken,
            amount - getPrice(),
            address(this),
            _msgSender()
        );

        emit Bought(_msgSender(), getPrice());
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
}
