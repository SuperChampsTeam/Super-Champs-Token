getMetagameMultiplier// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./SCAccessPassDefaultRenderer.sol";
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
    mapping(address => uint256) public passholderID;

    /// @notice Mapping of verification status by address
    mapping(address => bool) public _verified;

    /// @notice Mapping of metagame multiplier basis points by address
    mapping(address => uint256) public metagame_multiplier;

    /// @notice The price of minting an SBT
    uint256 public price = 0.001 ether;

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
        _renderer = new SCAccessPassDefaultRenderer(permissions_, name_, symbol_, uri_);
    }

    

    /// @notice Queries metagame multiplier of a specfied address's pass. 
    /// @param addr_ The address to query.
    /// @return _result uint256 Returns the rank of the user's access pass. Result is in basis points. 
    function getMetagameMultiplier(address addr_) external view returns (uint256 _multiplier) {
        _multiplier = metagame_multiplier[addr_];
	if(_multiplier == 0) 
	{
	    _multiplier = 10000;
        }
    }

    /// @notice Sets a player's metagame multiplier
    /// @dev Only callable by a systems admin.
    /// @param addr_ The address of the player.
    /// @param mult_bp_ Basis points of multiplier
    function setMetagameMultiplier(address addr_, uint256 mult_bp_) external isSystemsAdmin {
        metagame_multiplier[addr_] = mult_bp_;
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
    function setPrice(uint256 price_) external isSystemsAdmin {
        price = price_;
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
        require(passholderID[_msgSender()] == 0, "ALREADY MINTED SBT");
        require(msg.value == price, "INVALID PAYMENT");
        uint256 tokenId = _tokenIdCounter;
        _safeMint(_msgSender(), tokenId);
        passholderID[_msgSender()] = tokenId;
        _tokenIdCounter++;
    }

    /// @notice Mints an SBT to a recipient without requiring payment.
    /// @dev Callable only by Systems Admin.
    /// @param recipient_ The token recipient.
    function freeRegister(address recipient_) external isSystemsAdmin {
        require(passholderID[recipient_] == 0, "ALREADY MINTED SBT");
        uint256 tokenId = _tokenIdCounter;
        _safeMint(recipient_, tokenId);
        passholderID[recipient_] = tokenId;
        _tokenIdCounter++;
    }

    /// @notice Burns an SBT from a holder. May be used for future metagame functionality.
    /// @dev Callable only by Systems Admin.
    /// @param holder_ The token holder.
    function burnToken(address holder_) external isSystemsAdmin {
        uint256 _tokenId = passholderID[holder_];
        require(_tokenId != 0, "ALREADY MINTED SBT");
        _burn(_tokenId);
        passholderID[holder_] = 0;
    }

    /// @notice Queries if a specfied address has minted an SBT.
    /// @param addr_ The address to query.
    /// @return _result bool Returns true if the address has minted an SBT .
    function isPassHolder(address addr_) external view returns (bool _result) {
        _result = passholderID[addr_] > 0;
    }

    /// @notice Queries if a specfied address has been verified.
    /// @param addr_ The address to query.
    /// @return _result bool Returns true if the address has had its verification status set to true.
    function isVerified(address addr_) public view returns (bool _result) {
        _result = _verified[addr_];
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