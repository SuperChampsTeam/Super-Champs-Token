// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

interface IPermissionsManager{
    enum Role {
        ANY,
        GLOBAL_ADMIN,
        MINT_ADMIN,
        TRANSFER_ADMIN,
        SYSTEMS_ADMIN,
        EXT1,
        EXT2,
        EXT3,
        EXT4,
        EXT5
    }

    /**
    * @param role_ ISCPermissionsManager.Role to query
    * @param account_ Address to check for role_
    */
    function hasRole(Role role_, address account_) external view returns(bool);

    /**
    * @param role_ ISCPermissionsManager.Role to add
    * @param account_ Address to add role_ on
    */
    function addRole(Role role_, address account_) external returns(bool);

    /**
    * @param role_ ISCPermissionsManager.Role to remove
    * @param account_ Address to remove role_ from
    */
    function removeRole(Role role_, address account_) external returns(bool);
}