// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "../../interfaces/IPermissionsManager.sol";

/// @title The Super Champs Token (CHAMP)
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @dev Token transfers are restricted to addresses that have the Transer Admin permission
/// @notice This is a standard ERC20 token contract that restricts token transfers before it is unlocked.
contract SuperChampsToken is ERC20, ERC20Permit {
    ///@notice The protocol permissions registry
    IPermissionsManager immutable public permissions;
    
    ///@notice The total quantity of tokens minted by the tokenGenerationEvent(...) function
    uint256 public immutable TOTAL_SUPPLY;

    ///@notice A toggle that indicates if transfers are locked to Transfer Admins. Once this toggle is set to true, it cannot be unset.
    bool public transfersLocked;

    ///@notice A function modifier that restricts to Transfer Admins until transfersLocked is set to true.
    modifier isAdminOrUnlocked() {
        require(!transfersLocked || 
                permissions.hasRole(IPermissionsManager.Role.TRANSFER_ADMIN, _msgSender()) ||
                permissions.hasRole(IPermissionsManager.Role.TRANSFER_ADMIN, tx.origin),
                "NOT YET UNLOCKED");
        _;
    }

    ///@notice A function modifier that restricts to Global Admins
    modifier isGlobalAdmin() {
        require(permissions.hasRole(IPermissionsManager.Role.GLOBAL_ADMIN, _msgSender()),
                "ADMIN ONLY");
        _;
    }

    ///@param name_ String representing the token's name.
    ///@param symbol_ String representing the token's symbol.
    ///@param total_supply_ The total quantity of tokens that will be minted by the tokenGenerationEvent(...) function.
    ///@param permissions_ The protocol permissions registry.
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 total_supply_,
        IPermissionsManager permissions_
    ) 
        ERC20(name_, symbol_) 
        ERC20Permit(name_) 
    {
        TOTAL_SUPPLY = total_supply_;
        permissions = permissions_;
    }

    ///@notice The function that mints the token supply.
    ///@dev Only callable by a Global Admin. Only callable when no tokens have yet been minted.
    ///@param mint_recipients_ A list of addresses to mint tokens into.
    ///@param mint_quantities_ A list of token quantities to mint into the specified mint_recipients_. Total must equal TOTAL_SUPPLY.
    function tokenGenerationEvent(
        address[] memory mint_recipients_,
        uint256[] memory mint_quantities_)
        public isGlobalAdmin 
    {
        require(totalSupply() == 0, "TOKEN ALREADY GENERATED");
        require(mint_recipients_.length == mint_quantities_.length, "INCORRECT PARAM LENGTHS");
        require(permissions.hasRole(IPermissionsManager.Role.TRANSFER_ADMIN, address(this)), "TOKEN NOT TRANSFER ADMIN");
        
        for(uint256 i = 0; i < mint_recipients_.length; i++) {
            _mint(address(mint_recipients_[i]), mint_quantities_[i]);
        }

        require(totalSupply() == TOTAL_SUPPLY, "INCORRECT SUPPLY");
        transfersLocked = true;
    }

    ///@notice Identical to standard transfer function, except that transfers are restricted to Admins until transfersLocked is set. 
    function transfer(
        address to, 
        uint256 amount
    ) public override isAdminOrUnlocked returns(bool){
        return super.transfer(to, amount);
    }

    ///@notice Identical to standard transferFrom function, except that transfers are restricted to Admins until transfersLocked is set. 
    function transferFrom(
        address from, 
        address to, 
        uint256 amount
    ) public override isAdminOrUnlocked returns(bool) {
        return super.transferFrom(from, to, amount);
    }

    ///@notice Called to unlock transfers permanently. Token transfers cannot be locked after unlock.
    ///@dev Only callable by a Global Admin.
    function unlockTransfers() public isGlobalAdmin{
        transfersLocked = false;
    }

    /// @notice Transfer tokens that have been sent to this contract by mistake.
    /// @dev Only callable by address with Global Admin permissions. Cannot be called to withdraw emissions tokens.
    /// @param tokenAddress_ The address of the token to recover
    /// @param tokenAmount_ The amount of the token to recover
    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external isGlobalAdmin {
        IERC20(tokenAddress_).transfer(msg.sender, tokenAmount_);
    }
}