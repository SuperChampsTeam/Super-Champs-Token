// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

import "../../interfaces/IPermissionsManager.sol";

contract PermissionsManager is IPermissionsManager {
    mapping(address => mapping(Role => bool)) private role_mapping;
    mapping(address => uint256) private role_count;

    modifier onlyGlobal {
        require(hasRole(Role.GLOBAL_ADMIN, msg.sender));
        _;
    }

    constructor() {
        role_mapping[msg.sender][Role.GLOBAL_ADMIN] = true;
    }

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

    function addRole(Role role_, address account_) 
        external onlyGlobal 
        returns(bool) 
    {
        if(!role_mapping[account_][role_]) 
        {
            role_mapping[account_][role_] = true;
            role_count[account_]++;
        }
        return true;
    }

    function removeRole(Role role_, address account_) 
        external onlyGlobal 
        returns(bool) 
    {
        if(role_mapping[account_][role_]) 
        {
            role_mapping[account_][role_] = false;
            role_count[account_]--;
        }
        return true;
    }
}