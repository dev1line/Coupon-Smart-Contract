// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../lib/TransferHelper.sol";

/**
 *  @title  Dev Dutch Auction
 *
 *  @author CMC Global Team
 *
 *  @notice This smart contract set up an dutch auction with a NFT ERC-721
 *          that is the reward for highest bidder in countdown
 */
contract DutchAuction is OwnableUpgradeable {
    IERC721Upgradeable public nftReward;
    uint256 public nftId;
    uint256 public startingPrice;
    uint256 public discountRate;
    IERC20Upgradeable public paymentToken;
    uint256 public startTime;
    uint256 public endTime;

    function initialize(
        address _owner,
        IERC721Upgradeable _nft,
        uint256 _tokenId,
        IERC20Upgradeable _paymentToken,
        uint256 _startingBid,
        uint256 _startTime,
        uint256 _endTime
    ) public initializer {
        OwnableUpgradeable.__Ownable_init();
        transferOwnership(_owner);
        startTime = _startTime;
        endTime = _endTime;
        nftReward = _nft;
        nftId = _tokenId;
        startingPrice = _startingBid;
        paymentToken = _paymentToken;
    }

    function getPrice() public view returns (uint) {
        uint256 timeElapsed = block.timestamp - startTime;
        uint256 discount = discountRate * timeElapsed;
        return startingPrice - discount;
    }

    function withdraw() external onlyOwner {
        nftReward.safeTransferFrom(address(this), _msgSender(), nftId);
        selfdestruct(payable(owner()));
    }

    function buy(uint256 amount) external payable {
        require(startTime <= block.timestamp, "not started");
        require(block.timestamp < endTime, "ended");
        require(amount >= getPrice(), "value < price");

        TransferHelper._transferToken(
            paymentToken,
            amount,
            _msgSender(),
            address(this)
        );

        nftReward.safeTransferFrom(address(this), _msgSender(), nftId);

        if (amount - getPrice() > 0) {
            TransferHelper._transferToken(
                paymentToken,
                amount - getPrice(),
                address(this),
                _msgSender()
            );
        }
        selfdestruct(payable(owner()));
    }
}
