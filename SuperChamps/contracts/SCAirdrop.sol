// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IPermissionsManager.sol";
import "../interfaces/ISCSeasonRewards.sol";

contract SCAirdrop {
    IPermissionsManager immutable permissions;
    IERC20 immutable token;

    mapping(bytes => bool) private consumed_signatures;
    
    bool _reentrancy_locked;
    modifier nonreentrant {
        require(!_reentrancy_locked);
        _reentrancy_locked = true;
        _;
        _reentrancy_locked = false; 
    }

    event airdropClaimed(address recipient, uint256 amount);

    modifier isGlobalAdmin() {
        require(
            permissions.hasRole(IPermissionsManager.Role.GLOBAL_ADMIN, msg.sender));
        _;
    }

    constructor(address permissions_, address token_) {
        permissions = IPermissionsManager(permissions_);
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
    }

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
}