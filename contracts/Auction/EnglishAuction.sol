// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../lib/TransferHelper.sol";

/**
 *  @title  Dev English Auction
 *
 *  @author CMC Global Team
 *
 *  @notice This smart contract set up an english auction with a NFT ERC-721
 *          that is the reward for highest bidder
 */
contract EnglishAuction is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    IERC721Upgradeable public nftReward;
    uint256 public nftId;
    IERC20Upgradeable public paymentToken;
    uint256 public startTime;
    uint256 public endTime;

    address public highestBidder;
    uint256 public highestBid;
    mapping(address => uint256) public bids;

    event Start();
    event Bid(address indexed bidder, uint256 amount);
    event Withdraw(address indexed bidder, uint256 amount);
    event End(address indexed winner, uint256 amount);

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
        highestBid = _startingBid;
        startTime = _startTime;
        endTime = _endTime;
        nftReward = _nft;
        nftId = _tokenId;
        paymentToken = _paymentToken;
    }

    function bid(uint256 amount) external payable nonReentrant {
        require(startTime <= block.timestamp, "not started");
        require(block.timestamp < endTime, "ended");

        require(bids[_msgSender()] + amount > highestBid, "amount < highest");

        highestBidder = _msgSender();

        highestBid = bids[highestBidder] + amount;
        bids[highestBidder] = highestBid;

        TransferHelper._transferToken(
            paymentToken,
            amount,
            _msgSender(),
            address(this)
        );

        emit Bid(_msgSender(), amount);
    }

    function withdraw() external nonReentrant {
        uint256 balance = bids[_msgSender()];
        bids[_msgSender()] = 0;

        TransferHelper._transferToken(
            paymentToken,
            balance,
            address(this),
            _msgSender()
        );

        emit Withdraw(_msgSender(), balance);
    }

    function end() external onlyOwner {
        require(startTime <= block.timestamp, "not started");
        require(block.timestamp < endTime, "ended");

        if (highestBidder != address(0)) {
            nftReward.safeTransferFrom(address(this), highestBidder, nftId);
            TransferHelper._transferToken(
                paymentToken,
                highestBid,
                address(this),
                _msgSender()
            );
        } else {
            nftReward.safeTransferFrom(address(this), _msgSender(), nftId);
        }

        emit End(highestBidder, highestBid);
    }
}
