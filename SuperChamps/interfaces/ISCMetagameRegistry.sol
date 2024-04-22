// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

interface ISCMetagameRegistry {
    function metadataFromAddress(
        address address_,
        string calldata metadata_key_
    ) external view returns(string memory);

    function metadataFromUserID(
        string calldata user_id_,
        string calldata metadata_key_
    ) external view returns(string memory);

    function addressToUserID(
        address address_
    ) external view returns(string memory);

    function registerUserInfo (
        string memory user_id_,
        address add_address_,
        string memory updated_key_,
        string memory updated_value_,
        uint256 signature_expiry_ts_,
        uint256 signature_nonce_,
        bytes calldata signature_
    ) external;
}