// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./SCAccessPassRenderer.sol";
import "../../interfaces/ISCAccessPass.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../../interfaces/IERC721MetadataRenderer.sol";


/// @title Non-Fungible Soul Bound Token (SBT) with a small fee and optional metadata renderer.
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice The metadata renderer may be updated to add additional functionality to the SBT in the future.
contract SCAccessPass is ERC721, ISCAccessPass {
    /// @notice The metadata renderer contract.
    IERC721MetadataRenderer private _renderer;

    /// @notice The permissions registry.
    IPermissionsManager private immutable _permissions;

    /// @notice Mapping of SBT IDs by address
    mapping(address => uint256) private _passholder_id;

    /// @notice Mapping of verification status by address
    mapping(address => bool) private _verified;

    /// @notice Mapping of pass level by address
    mapping(address => uint256) private _pass_level;

    /// @notice The price of upgrading/minting an SBT. Entry 0 is the "upgrade" from level 0 (unowned to owned), ie mint price.
    uint256[] public upgrade_prices = [0.001 ether];

    /// @notice The token ID counter
    uint256 private _tokenIdCounter = 1;

    /// @notice Function modifier that requires the caller to have the systems admin permission set in _permissions
    modifier isSystemsAdmin() {
        require(_permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, msg.sender));
        _;
    }

    /// @notice Initializes a default renderer which returns a static URL that is identical for all tokens.
    /// @param permissions_ The permissions registry.
    /// @param name_ The name of the NFT collection.
    /// @param symbol_ The symbol of the NFT collection.
    /// @param uri_ The URI to return from the tokenURI() function.
    constructor(
        IPermissionsManager permissions_,
        string memory name_, 
        string memory symbol_,
        string memory uri_
    ) ERC721(name_, symbol_) { 
        _permissions = permissions_;
        _renderer = new SCAccessPassRenderer(permissions_, this, name_, symbol_, uri_);
    }

    /// @notice Queries level of a specfied address's pass. 
    /// @param addr_ The address to query.
    /// @return _level uint256 Returns the level of the user's access pass. Level 0 is unowned. Owned, level starts at 1.
    function getLevel(address addr_) public view returns (uint256 _level) {
        _level = _pass_level[addr_];
    }

    /// @notice Queries level of a specfied pass. 
    /// @param id_ The pass to query.
    /// @return _level uint256 Returns the level of the access pass. Level 0 is unowned. Owned, level starts at 1.
    function getLevel(uint256 id_) public view returns (uint256 _level) {
        address addr_ = ownerOf(id_);
        require(addr_ != address(0), "INVALID ID");
        _level = getLevel(addr_);
    }

    /// @notice Sets a new renderer contract.
    /// @dev Only callable by a systems admin.
    /// @param renderer_ The new renderer contract. Must conform to IERC721MetadataRenderer.
    function setRenderer(address renderer_) external isSystemsAdmin {
        _renderer = IERC721MetadataRenderer(renderer_);
    }

    /// @notice Sets a new price (in ether) for minting SBTs.
    /// @dev Only callable by a systems admin.
    /// @param price_ The new price.
    function setPrice(uint256 price_, uint256 level_) external isSystemsAdmin {
        require(level_ <= upgrade_prices.length, "CANT SKIP LEVELS");

        if(level_ == upgrade_prices.length) {
            upgrade_prices.push(price_);
        } else {
            upgrade_prices[level_] = price_;
        }
    }

    /// @notice Withdraws all minting fees.
    /// @dev Only callable by a systems admin.
    /// @param recipient_ The address to withdraw ether to.
    function collect(address payable recipient_) external isSystemsAdmin {
        require(address(this).balance > 0, "NO ETHER TO WITHDRAW");
        (bool sent, bytes memory data) = recipient_.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    /// @notice Sets the verification status of a passholder.
    /// @dev Only callable by a systems admin. May be used to set verification status on addresses that do not possess an SBT.
    /// @param holder_ The token holder whose status is being updated.
    function verifyPassHolder(address holder_, bool status_) external isSystemsAdmin {
        require(_verified[holder_] != status_, "ALREADY SET/UNSET");
        _verified[holder_] = status_;
    }

    /// @notice Mints an SBT.
    /// @dev Payable function. Requires msg.value to equal price.
    function register() external payable {
        require(_passholder_id[_msgSender()] == 0, "ALREADY MINTED SBT");
        require(msg.value == upgrade_prices[0], "INVALID PAYMENT");
        uint256 tokenId = _tokenIdCounter;
        _safeMint(_msgSender(), tokenId);
        setPassholderID(_msgSender(), tokenId);
        _pass_level[_msgSender()] = 1;
        _tokenIdCounter++;
    }

    /// @notice Mints an SBT to a recipient without requiring payment.
    /// @dev Callable only by Systems Admin.
    /// @param recipient_ The token recipient.
    function freeRegister(address recipient_) external isSystemsAdmin {
        require(_passholder_id[recipient_] == 0, "ALREADY MINTED SBT");
        uint256 tokenId = _tokenIdCounter;
        _safeMint(recipient_, tokenId);
        setPassholderID(recipient_, tokenId);
        _pass_level[recipient_] = 1;
        _tokenIdCounter++;
    }

    /// @notice Update level of an SBT.
    /// @dev Payable function. Requires msg.value to equal price.
    function upgrade() external payable {
        require(_passholder_id[_msgSender()] > 0, "MUST MINT SBT");
        uint256 level_ = _pass_level[_msgSender()];
        require(level_ < upgrade_prices.length, "MAX LEVEL");
        require(msg.value == upgrade_prices[level_], "INVALID PAYMENT");
        _pass_level[_msgSender()] = level_+1;
    }

    /// @notice Update level of an SBT of a recipient without requiring payment.
    /// @dev Callable only by Systems Admin.
    /// @param recipient_ The recipient whose SBT is receiving a level update.
    function freeUpgrade(address recipient_) external isSystemsAdmin {
        require(_passholder_id[recipient_] > 0, "MUST MINT SBT");
        uint256 level_ = _pass_level[recipient_];
        require(level_ < upgrade_prices.length, "MAX LEVEL");
        _pass_level[recipient_] = level_+1;
    }

    /// @notice Burns an SBT from a holder. May be used for future metagame functionality.
    /// @dev Callable only by Systems Admin.
    /// @param holder_ The token holder.
    function burnToken(address holder_) external isSystemsAdmin {
        uint256 _tokenId = _passholder_id[holder_];
        require(_tokenId != 0, "NON MINTED SBT");
        _burn(_tokenId);
        setPassholderID(holder_, 0);
        _pass_level[holder_] = 0;
    }

    /// @notice Queries if a specfied address has minted an SBT.
    /// @param addr_ The address to query.
    /// @return _result bool Returns true if the address has minted an SBT .
    function isPassHolder(address addr_) external view returns (bool _result) {
        _result = _passholder_id[addr_] > 0;
    }

    /// @notice Queries if a specfied address has been verified.
    /// @param addr_ The address to query.
    /// @return _result bool Returns true if the address has had its verification status set to true.
    function isVerified(address addr_) public view returns (bool _result) {
        _result = _verified[addr_];
    }

    ///@notice Map an SBT ID to it's owner's address bi-directionally.
    function setPassholderID(address addr_, uint256 id_) internal {
        _passholder_id[addr_] = id_;
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address, address, uint256) public pure override {
        require(false, "CANNOT TRANSFER SBT");
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
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return _renderer.tokenURI(tokenId);
    }
}