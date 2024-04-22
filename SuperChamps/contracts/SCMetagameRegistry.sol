// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

import "../interfaces/IPermissionsManager.sol";
import "../interfaces/ISCMetagameRegistry.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract SCMetagameRegistry is ISCMetagameRegistry, Context {
    IPermissionsManager immutable permissions;
    
    mapping(address => bytes32) private address_to_uid_hash;
    mapping(bytes32 => string) private uid_hash_to_user_id;

    mapping(bytes32 => mapping(string => string)) private metadata;
    mapping(bytes => bool) private consumed_signatures;
    mapping(string => uint256) public uid_hash_last_nonce;

    address test_sender;

    constructor(address permissions_) {
        permissions = IPermissionsManager(permissions_);
    }

    function hashMessage(
        string memory user_id_,
        address add_address_,
        string memory updated_key_,
        string memory updated_value_,
        uint256 signature_expiry_ts_,
        uint256 signature_nonce_
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            keccak256(abi.encodePacked(user_id_)),
            add_address_,
            keccak256(abi.encodePacked(updated_key_)),
            keccak256(abi.encodePacked(updated_value_)),
            signature_expiry_ts_,
            signature_nonce_
        ));
    }

    function metadataFromAddress(
        address address_,
        string calldata metadata_key_
    ) public view returns(string memory) {
        return metadata[address_to_uid_hash[address_]][metadata_key_];
    }

    function metadataFromUserID(
        string calldata user_id_,
        string calldata metadata_key_
    ) public view returns(string memory) {
        bytes32 _uid_hash =  keccak256(abi.encodePacked(user_id_));
        return metadata[_uid_hash][metadata_key_];
    }

    function addressToUserID(
        address address_
    ) public view returns(string memory) {
        return uid_hash_to_user_id[address_to_uid_hash[address_]];
    }

    function registerUserInfo (
        string memory user_id_,
        address add_address_,
        string memory updated_key_,
        string memory updated_value_,
        uint256 signature_expiry_ts_,
        uint256 signature_nonce_,
        bytes calldata signature_
    ) public {
        if(signature_.length > 0) {
            require(signature_expiry_ts_ > block.timestamp, "INVALID EXPIRY");
            require(uid_hash_last_nonce[user_id_] < signature_nonce_, "CONSUMED NONCE");
            require(!consumed_signatures[signature_], "CONSUMED SIGNATURE");
            
            uid_hash_last_nonce[user_id_] = signature_nonce_;
            consumed_signatures[signature_] = true;

            bytes32 _messageHash = hashMessage(
                user_id_,
                add_address_,
                updated_key_,
                updated_value_,
                signature_expiry_ts_,
                signature_nonce_
            );

            _messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
            
            (bytes32 _r, bytes32 _s, uint8 _v) = _splitSignature(signature_);
            address _signer = ecrecover(_messageHash, _v, _r, _s);
            require(permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, _signer), "INVALID SIGNER");
        } else {
            require(permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, _msgSender()), "NOT AUTHORIZED");
        }

        bytes32 _uid_hash =  keccak256(abi.encodePacked(user_id_));
        uid_hash_to_user_id[_uid_hash] = user_id_;

        require(address_to_uid_hash[add_address_] == 0, "ADDRESS ALREADY REGISTERED");
        address_to_uid_hash[add_address_] = _uid_hash;

        mapping(string => string) storage user_metadata = metadata[_uid_hash];
        
        user_metadata[updated_key_] = updated_value_;
    }

    function TEST_overrideSender(address sender) external {
        require(permissions.hasRole(IPermissionsManager.Role.GLOBAL_ADMIN, msg.sender));
        test_sender = sender;
    }

    function _splitSignature(bytes memory sig_)
        private pure
        returns (bytes32 _r, bytes32 _s, uint8 _v)
    {
        require(sig_.length == 65, "INVALID SIGNATURE LENGTH");

        assembly {
            _r := mload(add(sig_, 32))
            _s := mload(add(sig_, 64))
            _v := byte(0, mload(add(sig_, 96)))
        }
    }

    function _msgSender() internal override view virtual returns (address) {
        if(test_sender == address(0)) return msg.sender;
        return test_sender;
    }
}