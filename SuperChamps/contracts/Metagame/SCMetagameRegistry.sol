// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../Utils/SCPermissionedAccess.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../../interfaces/ISCMetagameRegistry.sol";

/// @title Metagame metadata registry.
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice Used to store arbitrary metadata associated with specific user IDs and Addresses.
/// @dev Metadata is stored in a key-value store that maps string metadata keys to string values. Lookup can be indexed from user ID or from address.
contract SCMetagameRegistry is ISCMetagameRegistry, SCPermissionedAccess {   
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Mapping of addresses to user id hashes
    mapping(address => string) private address_to_uid;

    /// @notice Mapping of user id hashes to user ids
    mapping(string => EnumerableSet.AddressSet) private uid_to_address;

    /// @notice Mapping of user id hashes to a mapping of metadata keys to values
    mapping(string => mapping(string => string)) private string_metadata;

    /// @notice Mapping of user id hashes to a mapping of metadata keys to uint values
    mapping(string => mapping(string => uint256)) private uint_metadata;

    /// @param permissions_ Address of the protocol permissions registry. Must conform to IPermissionsManager
    constructor(address permissions_) SCPermissionedAccess(permissions_) {}

    /// @notice Used to query a metadata value for a user by a specified address and key
    /// @param address_ Address of the user
    /// @param metadata_key_ String of the key being queried for the specified address's user
    /// @return string The stored value for the queried user/key pair. Returns "" if no data is stored for the user in that key, or, if there is no user associated with the address.
    function metadataString(
        address address_,
        string memory metadata_key_
    ) public view returns(string memory) {
        return metadataString(address_to_uid[address_], metadata_key_);
    }

    /// @notice Used to query a metadata value for a user by a specified user id and key
    /// @param user_id_ ID of the user
    /// @param metadata_key_ String of the key being queried for the specified user
    /// @return string The stored value for the queried user/key pair. Returns "" if no data is stored for that user in that key.
    function metadataString(
        string memory user_id_,
        string memory metadata_key_
    ) public view returns(string memory) {
        return string_metadata[user_id_][metadata_key_];
    }

    /// @notice Used to query a metadata value for a user by a specified address and key
    /// @param address_ Address of the user
    /// @param metadata_key_ String of the key being queried for the specified address's user
    /// @return string The stored value for the queried user/key pair. Returns "" if no data is stored for the user in that key, or, if there is no user associated with the address.
    function metadataUInt(
        address address_,
        string memory metadata_key_
    ) public view returns(uint256) {
        return metadataUInt(address_to_uid[address_], metadata_key_);
    }

    /// @notice Used to query a metadata value for a user by a specified user id and key
    /// @param user_id_ ID of the user
    /// @param metadata_key_ String of the key being queried for the specified user
    /// @return string The stored value for the queried user/key pair. Returns "" if no data is stored for that user in that key.
    function metadataUInt(
        string memory user_id_,
        string memory metadata_key_
    ) public view returns(uint256) {
        return uint_metadata[user_id_][metadata_key_];
    }

    /// @notice Used to query a user ID from an address
    /// @param address_ Address to query a user ID from
    /// @return string The user ID associated with the specified address. Returns "" if not associated with a user.
    function addressToUserID(
        address address_
    ) public view returns(string memory) {
        return address_to_uid[address_];
    }

    /// @notice Associate an address with a user id
    /// @param user_id_ User ID to add an address to
    /// @param address_ Address to add to user
    /// @dev Error if address is registered to another uid
    function registerUserAddress (
        string memory user_id_,
        address address_
    ) public isSystemsAdmin{
        require(bytes(addressToUserID(address_)).length == 0, "ADDRESS ALREADY REGISTERED");
        uid_to_address[user_id_].add(address_);
        address_to_uid[address_] = user_id_;
    }

    /// @notice Disassociate an address with a user id
    /// @param user_id_ User ID to remove an address from
    /// @param address_ Address to remove from user
    /// @dev Error if address is registered to another uid
    function removeUserAddress (
        string memory user_id_,
        address address_
    ) public isSystemsAdmin{
        require(
            keccak256(abi.encodePacked(address_to_uid[address_])) == 
            keccak256(abi.encodePacked(user_id_)), 
            "ADDRESS NOT REGISTERED");

        uid_to_address[user_id_].remove(address_);
        address_to_uid[address_] = "";
    }

    /// @notice Set metadata string by address
    /// @param address_ Address to remove from user
    /// @param metadata_key_ String key of metadata element
    /// @param metadata_value_ String value of metadata element
    /// @dev Error if address is not registered to a uid
    /// @dev Only callable by systems admin
    function setMetadata(
        address address_,
        string memory metadata_key_,
        string memory metadata_value_
    ) public isSystemsAdmin {
        string memory _uid = address_to_uid[address_];
        setMetadata(_uid, metadata_key_, metadata_value_);
    }

    /// @notice Set metadata string by user id
    /// @param uid_ User ID
    /// @param metadata_key_ String key of metadata element
    /// @param metadata_value_ String value of metadata element
    /// @dev Error if address is not registered to a uid
    /// @dev Only callable by systems admin
    function setMetadata(
        string memory uid_,
        string memory metadata_key_,
        string memory metadata_value_
    ) public isSystemsAdmin {
        require(bytes(uid_).length > 0, "NOT REGISTERED");
        string_metadata[uid_][metadata_key_] = metadata_value_;
    }

    /// @notice Set metadata string by address
    /// @param address_ Address to remove from user
    /// @param metadata_key_ String key of metadata element
    /// @param metadata_value_ uint256 value of metadata element
    /// @dev Error if address is not registered to a uid
    /// @dev Only callable by systems admin
    function setMetadata(
        address address_,
        string memory metadata_key_,
        uint256 metadata_value_
    ) public isSystemsAdmin {
        string memory _uid = address_to_uid[address_];
        setMetadata(_uid, metadata_key_, metadata_value_);
    }

    /// @notice Set metadata string by user id.
    /// @param uid_ User ID
    /// @param metadata_key_ String key of metadata element
    /// @param metadata_value_ uint256 value of metadata element
    /// @dev Error if address is not registered to a uid
    /// @dev Only callable by systems admin
    function setMetadata(
        string memory uid_,
        string memory metadata_key_,
        uint256 metadata_value_
    ) public isSystemsAdmin {
        require(bytes(uid_).length > 0, "NOT REGISTERED");
        uint_metadata[uid_][metadata_key_] = metadata_value_;
    }

    /// @notice Transfer tokens that have been sent to this contract by mistake.
    /// @dev Only callable by address with Global Admin permissions. Cannot be called to withdraw emissions tokens.
    /// @param tokenAddress_ The address of the token to recover
    /// @param tokenAmount_ The amount of the token to recover
    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external isGlobalAdmin {
        IERC20(tokenAddress_).transfer(msg.sender, tokenAmount_);
    }
}