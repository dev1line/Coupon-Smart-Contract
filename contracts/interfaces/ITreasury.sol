// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface ITreasury is IERC165Upgradeable {
    function distribute(
        IERC20Upgradeable _paymentToken,
        address _to,
        uint256 _amount
    ) external;
}
