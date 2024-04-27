// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IPermissionsManager.sol";

/// @title The Super Champs protocol permissions registry.
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice This is a key-value store that maps addresses to permissions sets. 
/// @dev A single instance must be used by the entire protocol. 
contract PermissionsManager is IPermissionsManager {
    ///@notice A mapping of addresses to a set of roles that those addresses have.
    mapping(address => mapping(Role => bool)) private role_mapping;

    ///@notice A mapping of addresses to the quantity of roles that they possess.
    ///@dev Utilized to track Admin membership for IPermissionsManager.Role.ANY
    mapping(address => uint256) private role_count;

    ///@notice A function modifier that restricts execution to Global Admins
    modifier isGlobalAdmin {
        require(hasRole(Role.GLOBAL_ADMIN, msg.sender));
        _;
    }

    constructor() {
        role_mapping[msg.sender][Role.GLOBAL_ADMIN] = true;
    }

    ///@notice Queries if an address has the specified role.
    ///@param role_ The role to query.
    ///@param account_ The account to query.
    ///@return bool True if account_ has the Role role_.
    function hasRole(Role role_, address account_) 
        public view 
        returns(bool) 
    {
        if(role_ == IPermissionsManager.Role.ANY)
        {
            return role_count[account_] > 0;
        }
        else 
        {
            return  role_mapping[account_][role_] || 
                    role_mapping[account_][Role.GLOBAL_ADMIN];
        }
    }

    ///@notice Adds a role to an account.
    ///@param role_ The role to add.
    ///@param account_ The account to add a role to.
    function addRole(Role role_, address account_) 
        external isGlobalAdmin 
    {
        if(!role_mapping[account_][role_]) 
        {
            role_mapping[account_][role_] = true;
            role_count[account_]++;
        }
    }

    ///@notice Removes a role from an account.
    ///@dev msg.sender cannot remove the Global role from self, to prevent a scenario where no account retains the Global Admin role.
    ///@param role_ The role to remove.
    ///@param account_ The account to remove a role from.
    function removeRole(Role role_, address account_) 
        external isGlobalAdmin 
    {
        require(account_ != msg.sender || role_ != Role.GLOBAL_ADMIN, "CAN'T REMOVE GLOBAL FROM SELF");
        if(role_mapping[account_][role_]) 
        {
            role_mapping[account_][role_] = false;
            role_count[account_]--;
        }
    }

    /// @notice Transfer tokens that have been sent to this contract by mistake.
    /// @dev Only callable by address with Global Admin permissions. Cannot be called to withdraw emissions tokens.
    /// @param tokenAddress_ The address of the token to recover
    /// @param tokenAmount_ The amount of the token to recover
    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external isGlobalAdmin {
        IERC20(tokenAddress_).transfer(msg.sender, tokenAmount_);
    }
}