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
    /// @notice The metadata renderer contract.
    IERC721MetadataRenderer private _renderer;
    
    ///@notice The protocol token;
    ISuperChampsToken public immutable champ_token;

    /// @notice Token IDs to Type
    mapping(uint256 => uint256) public _token_species;

    /// @notice Set of token IDs which are tradeable
    mapping(uint256 => bool) public _unlocked_tokens;

    /// @notice Set of token species which are tradeable
    mapping(uint256 => bool) public _unlocked_species;

    /// @notice Set of token groups which are tradeable
    mapping(uint128 => bool) public _unlocked_groups;

    bool _all_unlocked;

    ///@notice A function modifier that restricts to Transfer Admins until transfersLocked is set to true.
    modifier isAdminOrUnlocked(uint256 token_id_) {
        uint256 _species = _token_species[token_id_];
        uint128 _group = uint128(_species >> 128);

        require(_all_unlocked || 
                _unlocked_species[_species] || _unlocked_groups[_group] || _unlocked_tokens[token_id_] || 
                permissions.hasRole(IPermissionsManager.Role.TRANSFER_ADMIN, _msgSender()) ||
                permissions.hasRole(IPermissionsManager.Role.TRANSFER_ADMIN, tx.origin),
                "NOT YET UNLOCKED");
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
    function mintTo(address recipient_, uint256 token_id_, uint128 species_, uint128 group_) external isSystemsAdmin {
        _safeMint(recipient_, token_id_);
        uint256 _species = (group_ << 128) | species_;
        _token_species[token_id_] = _species;
    }

    ///@notice Identical to standard transferFrom function, except that transfers are restricted to Admins until transfersLocked is set. 
    function transferFrom(
        address from_, 
        address to_, 
        uint256 token_id_
    ) public override isAdminOrUnlocked(token_id_) {
        return super.transferFrom(from_, to_, token_id_);
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

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 token_id_) public view override returns (string memory) {
        _requireOwned(token_id_);
        uint256[] memory _token_id_elements = new uint256[](3);
        uint256 _species_group = _token_species[token_id_];
        uint128 _species = uint128(_species_group);
        uint128 _group = uint128(_species_group >> 128);
        _token_id_elements[0] = _group;
        _token_id_elements[1] = _species;
        _token_id_elements[2] = token_id_;
        return _renderer.tokenURI(_token_id_elements);
    }
}