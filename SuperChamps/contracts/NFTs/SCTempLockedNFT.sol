// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Utils/SCPermissionedAccess.sol";
import "./SCGenericRenderer.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../../interfaces/ISuperChampsToken.sol";
import "../../interfaces/IERC721MetadataRenderer.sol";

/// @title Super Champs (CHAMP) Temporarily Transfer Locked NFT
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @dev Token transfers are restricted to addresses that have the Transer Admin permission until the token/collection is unlocked.
/// @notice This is a standard ERC721 token contract that restricts token transfers before the token is unlocked. Trades still possible via Shop/Marketplace system.
contract SCTempLockedNFT is ERC721, SCPermissionedAccess {
    struct TokenData {
        uint96 group;
        uint96 species;
        uint64 expiry;
    }

    /// @notice The metadata renderer contract.
    IERC721MetadataRenderer private _renderer;
    
    ///@notice The protocol token;
    ISuperChampsToken public immutable champ_token;

    /// @notice Token IDs to Type
    mapping(uint256 => TokenData) public _token_data;

    /// @notice Set of token IDs which are tradeable
    mapping(uint256 => bool) public _unlocked_tokens;

    /// @notice Set of token species which are tradeable
    mapping(uint256 => bool) public _unlocked_species;

    /// @notice Set of token groups which are tradeable
    mapping(uint128 => bool) public _unlocked_groups;

    bool _all_unlocked;

    ///@notice A function modifier that restricts to Transfer Admins until transfersLocked is set to true.
    modifier isAdminOrUnlocked(uint256 token_id_) {
        
        require(isUnlocked(token_id_) || 
                permissions.hasRole(IPermissionsManager.Role.TRANSFER_ADMIN, _msgSender()) ||
                permissions.hasRole(IPermissionsManager.Role.TRANSFER_ADMIN, tx.origin),
                "NOT UNLOCKED");
        _;
    }

    ///@param name_ String representing the token's name.
    ///@param symbol_ String representing the token's symbol.
    ///@param permissions_ The protocol permissions manager.
    constructor(
        string memory name_,
        string memory symbol_,
        string memory uri_,
        address permissions_
    ) 
        ERC721(name_, symbol_) SCPermissionedAccess(permissions_)
    {
        _renderer = new SCGenericRenderer(permissions, name_, symbol_, uri_);
    }

    /// @notice Sets a new renderer contract.
    /// @dev Only callable by a systems admin.
    /// @param renderer_ The new renderer contract. Must conform to IERC721MetadataRenderer.
    function setRenderer(address renderer_) external isSystemsAdmin {
        _renderer = IERC721MetadataRenderer(renderer_);
    }

    /// @notice Mints an NFT to a recipient.
    /// @dev Callable only by Systems Admin. Sales costs and administration should be performed off-chain or in a separate sales contract.
    /// @param recipient_ The token recipient.
    /// @param token_id_ The id of the token
    /// @param species_ The template of the token's metadata identity
    /// @param group_ The group that the species_ belongs to
    /// @param expiry_ The timestamp at which the token expires
    /// @dev If expiry_ is 0, the token does not expire
    function mintTo(address recipient_, uint256 token_id_, uint96 species_, uint96 group_, uint64 expiry_) external isSystemsAdmin {
        require(expiry_ == 0 || expiry_ > block.timestamp, "CANNOT MINT EXPIRED");
        require(_token_data[token_id_].group == 0 && _token_data[token_id_].species == 0, "ALREADY MINTED");
        _safeMint(recipient_, token_id_);
        TokenData memory _data = TokenData(group_, species_, expiry_);
        _token_data[token_id_] = _data;
    }

    ///@notice Identical to standard transferFrom function, except that transfers are restricted to Admins until transfersLocked is set. 
    function transferFrom(
        address from_, 
        address to_, 
        uint256 token_id_
    ) public override isAdminOrUnlocked(token_id_) {
        return super.transferFrom(from_, to_, token_id_);
    }

    ///@notice Adds extra seconds to a specific token's expiry time
    ///@param token_id_ The id of the token which is to have its expiry time extended
    ///@param add_seconds_ The number of seconds to add to the token's expiry time
    ///@dev This cannot effect a token with expiry of 0, as this indicates the token never expires
    ///@dev The new expiry time must be in the future
    function extendExpiry(uint256 token_id_, uint64 add_seconds_) public isSystemsAdmin {
        uint64 _expiry = _token_data[token_id_].expiry;
        require(_expiry > 0, "CANNOT EXTEND NON-EXPIRING TOKEN");

        _expiry += add_seconds_;
        require(_expiry > block.timestamp, "NOT ENOUGH TIME");
        
        _token_data[token_id_].expiry = _expiry;
    }

    ///@notice Burns tokens that are expired.
    ///@param expired_token_ids_ A list of token ids which are to be cleaned up (burned)
    function cleanup(uint256[] memory expired_token_ids_) public isSystemsAdmin {
        for(uint256 i = 0; i < expired_token_ids_.length; i++) {
            uint256 _token_id = expired_token_ids_[i];
            uint256 _expired = _token_data[_token_id].expiry;
            if(_expired > 0 && _expired < block.timestamp) {
                _burn(_token_id);
            }
        }
    }

    ///@notice Used to unlock specific token ids for trading
    ///@param token_ids_ A list of token ids that are to be unlocked
    function unlockTokens(
        uint256[] memory token_ids_
    ) public isSystemsAdmin {
        uint256 len = token_ids_.length - 1;
        for(uint256 i = len; i >= 0; i--) {
            _unlocked_tokens[token_ids_[i]] = true;
        }
    }

    ///@notice Used to unlock a group of SBTs for trading
    ///@param group_ A group id that is to be unlocked
    function unlockTokenGroup(
        uint128 group_
    ) public isSystemsAdmin {
        _unlocked_groups[group_] = true;
    }

    ///@notice Used to unlock a species of SBT for trading
    ///@param species_ A species id that is to be unlocked
    ///@param group_ The group id that the species belongs to
    function unlockTokenSpecies(
        uint128 species_,
        uint128 group_
    ) public isSystemsAdmin {
        uint256 _full_species = (group_ << 128) | species_;
        _unlocked_species[_full_species] = true;
    }

    ///@notice Used to lock/unlock all tokens in the collection for trading
    ///@param unlocked_ The unlock state that is to be set
    function unlockCollection(bool unlocked_) public isSystemsAdmin {
        _all_unlocked = unlocked_;
    }

    ///@notice Returns the unlocked state of a specific token
    ///@param token_id_ The token id to query
    function isUnlocked(uint256 token_id_) public view returns (bool _unlocked_) {
        TokenData memory _data = _token_data[token_id_];
        _unlocked_ = _all_unlocked || 
                     _unlocked_species[_data.species] || 
                     _unlocked_groups[_data.group] || 
                     _unlocked_tokens[token_id_];
    }

    /// @notice Transfer tokens that have been sent to this contract by mistake.
    /// @dev Only callable by address with Global Admin permissions. Cannot be called to withdraw emissions tokens.
    /// @param tokenAddress_ The address of the token to recover
    /// @param tokenAmount_ The amount of the token to recover
    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external isGlobalAdmin {
        IERC20(tokenAddress_).transfer(msg.sender, tokenAmount_);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view override returns (string memory) {
        return _renderer.name();
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view override returns (string memory) {
        return _renderer.symbol();
    }

    function _ownerOf(uint256 token_id_) internal override view returns (address _owner_) {
        uint64 _expiry = _token_data[token_id_].expiry;
        if(_expiry > 0 && _expiry < block.timestamp) {
            _owner_ = address(0);
        } else {
            _owner_ = super._ownerOf(token_id_);
        }
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 token_id_) public view override returns (string memory) {
        _requireOwned(token_id_);

        TokenData memory _data = _token_data[token_id_];        
        uint256[] memory _token_id_elements = new uint256[](4);
        _token_id_elements[0] = _data.group;
        _token_id_elements[1] = _data.species;
        _token_id_elements[2] = token_id_;
        _token_id_elements[3] = _data.expiry;
        
        return _renderer.tokenURI(_token_id_elements);
    }
}