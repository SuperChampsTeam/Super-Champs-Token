// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IPermissionsManager.sol";

contract SCShop {
    IPermissionsManager immutable permissions;
    IERC20 immutable token;

    event saleReceipt(address buyer, uint256 amount, string subsystem, string metadata);

    modifier isSalesAdmin() {
        require(permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, msg.sender));
        _;
    }

    constructor(address permissions_, address token_) {
        permissions = IPermissionsManager(permissions_);
        token = IERC20(token_);
    }

    function saleTransaction (
        address buyer,
        address till,
        uint256 amount, 
        string calldata subsystem, 
        string calldata metadata
    ) public isSalesAdmin
    {
        bool success = token.transferFrom(buyer, till, amount);
        require(success);

        emit saleReceipt(buyer, amount, subsystem, metadata);
    }
}