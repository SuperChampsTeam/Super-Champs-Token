// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Utils/SCPermissionedAccess.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../../interfaces/ISCSeasonRewards.sol";

/// @title Token Rewards Faucet
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice This contract that allows arbitrary addresses to claim reward tokens by providing a valid signature
contract SCRewardsDispenser is SCPermissionedAccess {
    ///@notice The reward token that this contract manages
    IERC20 immutable token;

    ///@notice A set of consumed message signature hashes
    ///@dev Members of the set are not valid signatures
    mapping(bytes => bool) private consumed_signatures;

    ///@notice Emitted when an account claims reward tokens
    event rewardClaimed(address recipient, uint256 amount);

    ///@param permissions_ The address of the protocol permissions registry. Must conform to IPermissionsManager.
    ///@param token_ The address of the rewawd token. Must conform to IERC20.
    constructor(address permissions_, address token_) SCPermissionedAccess(permissions_) {
        token = IERC20(token_);
    }

    function claim(
        uint256 amount_,
        uint256 signature_expiry_ts_,
        bytes memory signature_
    ) external 
    {
        require(signature_expiry_ts_ > block.timestamp, "INVALID EXPIRY");
        require(!consumed_signatures[signature_], "CONSUMED SIGNATURE");
        
        consumed_signatures[signature_] = true;

        bytes32 _messageHash = keccak256(
            abi.encode(msg.sender, amount_, signature_expiry_ts_));
        _messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
        
        (bytes32 _r, bytes32 _s, uint8 _v) = _splitSignature(signature_);
        address _signer = ecrecover(_messageHash, _v, _r, _s);
        require(permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, _signer), "INVALID SIGNER");

        token.transfer(msg.sender, amount_);
        emit rewardClaimed(msg.sender, amount_);
    }

    /// @notice Used to split a signature into r,s,v components which are required to recover a signing address.
    /// @param sig_ The signature to split
    /// @return _r bytes32 The r component
    /// @return _s bytes32 The s component
    /// @return _v bytes32 The v component
    function _splitSignature(bytes memory sig_)
        public
        pure
        returns (bytes32 _r, bytes32 _s, uint8 _v)
    {
        require(sig_.length == 65, "invalid signature length");

        assembly {
            _r := mload(add(sig_, 32))
            _s := mload(add(sig_, 64))
            _v := byte(0, mload(add(sig_, 96)))
        }
    }

    function withdraw() 
        external isGlobalAdmin
    {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    /// @notice Transfer tokens that have been sent to this contract by mistake.
    /// @dev Only callable by address with Global Admin permissions. Cannot be called to withdraw emissions tokens.
    /// @param tokenAddress_ The address of the token to recover
    /// @param tokenAmount_ The amount of the token to recover
    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external isGlobalAdmin {
        IERC20(tokenAddress_).transfer(msg.sender, tokenAmount_);
    }
}