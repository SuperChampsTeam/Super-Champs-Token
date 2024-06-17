// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;
import "../Utils/SCPermissionedAccess.sol";

/// @title SuperChamps Game Events Logger
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice A permissioned events logger. Used for tracking virtual asset transactions on chain, via events only.
contract SCVirtualAssetEvents is SCPermissionedAccess {
    mapping(address => bool) _permissions_users;

    event GameUserAsset(string game, string user_id, string asset_id, int256 delta, string data);
    event EcosystemUserAsset(string user_id, string asset_id, int256 delta, string data);
    event GameUserActivity(string game, string user_id, string data);
    event EcosystemUserActivity(string user_id, string data);

    modifier isPermissionedUser() {
        require(_permissions_users[msg.sender], "NOT PERMISSIONED USER");
        _;
    }

    constructor(address permissions_) SCPermissionedAccess(permissions_) { }

    function PermissionUser(address[] memory users, bool state) external isSystemsAdmin {
        uint256 len = users.length;
        for(uint256 i = 0; i < len; i++) {
            _permissions_users[users[i]] = state;
        }
    }

    function EmitGameUserAsset(string memory game, string memory user_id, string memory asset_id, int256 delta, string memory data) external isPermissionedUser {
        emit GameUserAsset(game, user_id, asset_id, delta, data);
    }

    function EmitEcosystemUserAsset(string memory user_id, string memory asset_id, int256 delta, string memory data) external isPermissionedUser {
        emit EcosystemUserAsset(user_id, asset_id, delta, data);
    }

    function EmitGameUserActivity(string memory game, string memory user_id, string memory data) external isPermissionedUser {
        emit GameUserActivity(game, user_id, data);
    }

    function EmitEcosystemUserActivity(string memory user_id, string memory data) external isPermissionedUser {
        emit EcosystemUserActivity(user_id, data);
    }
}