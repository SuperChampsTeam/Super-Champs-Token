// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

/// @title Interface for protocol metagame metadata registry
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
interface ISCMetagameRegistry {
    function metadataString(
        address address_,
        string memory metadata_key_
    ) external view returns(string memory);

    function metadataString(
        string memory user_id_,
        string memory metadata_key_
    ) external view returns(string memory);

    function metadataUInt(
        address address_,
        string memory metadata_key_
    ) external view returns(uint256);

    function metadataUInt(
        string memory user_id_,
        string memory metadata_key_
    ) external view returns(uint256);

    function addressToUserID(
        address address_
    ) external view returns(string memory);

    function registerUserAddress (
        string memory user_id_,
        address address_
    ) external;

    function removeUserAddress (
        string memory user_id_,
        address address_
    ) external;

    function setMetadata(
        address address_,
        string memory metadata_key_,
        string memory metadata_value_
    ) external;

    function setMetadata(
        address address_,
        string memory metadata_key_,
        uint metadata_value_
    ) external;

    function setMetadata(
        string memory uid_,
        string memory metadata_key_,
        string memory metadata_value_
    ) external;

    function setMetadata(
        string memory uid_,
        string memory metadata_key_,
        uint metadata_value_
    ) external;
}