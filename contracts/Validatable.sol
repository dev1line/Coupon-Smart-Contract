// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

import "./interfaces/IAdmin.sol";
import "./lib/ErrorHelper.sol";

/**
 *  @title  Dev Validatable
 *
 *  @author CMC Global Team
 *
 *  @dev This contract is using as abstract smart contract
 *  @notice This smart contract provide the validatable methods and modifier for the inheriting contract.
 */
contract Validatable is PausableUpgradeable {
    /**
     *  @notice IAdmin is interface of Admin contract
     */
    IAdmin public admin;

    event SetPause(bool indexed isPause);

    /*------------------Check Admins------------------*/

    modifier onlyOwner() {
        if (admin.owner() != _msgSender()) {
            revert ErrorHelper.CallerIsNotOwner();
        }
        _;
    }

    modifier onlyAdmin() {
        if (!admin.isAdmin(_msgSender())) {
            revert ErrorHelper.CallerIsNotOwnerOrAdmin();
        }
        _;
    }

    modifier validWallet(address _account) {
        if (!isWallet(_account)) {
            revert ErrorHelper.InvalidWallet(_account);
        }
        _;
    }

    /*------------------Common Checking------------------*/

    modifier notZeroAddress(address _account) {
        if (_account == address(0)) {
            revert ErrorHelper.InvalidAddress();
        }
        _;
    }

    modifier notZero(uint256 _amount) {
        if (_amount == 0) {
            revert ErrorHelper.InvalidAmount();
        }
        _;
    }

    modifier validPaymentToken(IERC20Upgradeable _paymentToken) {
        if (!admin.isPermittedPaymentToken(_paymentToken)) {
            revert ErrorHelper.PaymentTokenIsNotSupported();
        }
        _;
    }

    modifier validAdmin(IAdmin _account) {
        if (
            !ERC165CheckerUpgradeable.supportsInterface(
                address(_account),
                type(IAdmin).interfaceId
            )
        ) {
            revert ErrorHelper.InValidAdminContract(address(_account));
        }
        _;
    }

    /*------------------Initializer------------------*/

    function __Validatable_init(
        IAdmin _admin
    ) internal onlyInitializing validAdmin(_admin) {
        __Context_init();
        __Pausable_init();

        admin = _admin;
    }

    /*------------------Contract Interupts------------------*/

    /**
     *  @notice Set pause action
     */
    function setPause(bool isPause) public onlyOwner {
        if (isPause) _pause();
        else _unpause();

        emit SetPause(isPause);
    }

    /**
     *  @notice Check contract is paused.
     */
    function isPaused() public view returns (bool) {
        return super.paused();
    }

    /*------------------Checking Functions------------------*/

    /**
     *  @notice Check whether merkle tree proof is valid
     *
     *  @param  _proof      Proof data of leaf node
     *  @param  _root       Root data of merkle tree
     *  @param  _account    Address of an account to verify
     */
    function isValidProof(
        bytes32[] memory _proof,
        bytes32 _root,
        address _account
    ) public pure returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_account));
        return MerkleProofUpgradeable.verify(_proof, _root, leaf);
    }

    function isWallet(address _account) public view returns (bool) {
        return
            _account != address(0) &&
            !AddressUpgradeable.isContract(_account) &&
            tx.origin == _msgSender();
    }
}
