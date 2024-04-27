// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

/// @title Interface for protocol permissions registry
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
interface IPermissionsManager{
    ///@notice All available roles.
    ///@dev EXT roles are available for future application.
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
        EXT5,
        EXT6,
        EXT7,
        EXT8,
        EXT9,
        EXT10
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
    function addRole(Role role_, address account_) external;

    /**
    * @param role_ ISCPermissionsManager.Role to remove
    * @param account_ Address to remove role_ from
    */
    function removeRole(Role role_, address account_) external;
}