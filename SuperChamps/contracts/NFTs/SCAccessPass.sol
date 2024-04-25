// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./SCAccessPassDefaultRenderer.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../../interfaces/IERC721MetadataRenderer.sol";

//Non-Fungible Soul Bound Token (SBT)
contract SCAccessPass is ERC721 {
    IERC721MetadataRenderer private _renderer;

    IPermissionsManager private immutable _permissions;
    mapping(address => uint256) public passholderID;
    mapping(address => bool) public _verified;
    uint256 public price = 0.001 ether;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    modifier isSystemsAdmin() {
        require(_permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, msg.sender));
        _;
    }

    constructor(
        IPermissionsManager permissions_,
        string memory name_, 
        string memory symbol_
    ) ERC721(name_, symbol_) { 
        _permissions = permissions_;
        _renderer = new SCAccessPassDefaultRenderer(permissions_, name_, symbol_);
    }

    function setRenderer(address renderer_) external isSystemsAdmin {
        _renderer = IERC721MetadataRenderer(renderer_);
    }

    function setPrice(uint256 price_) external isSystemsAdmin {
        price = price_;
    }

    function collect(address payable recipient_) external isSystemsAdmin {
        recipient_.transfer(address(this).balance);
    }

    function verifyPassHolder(address holder_, bool status_) external isSystemsAdmin {
        require(_verified[holder_] != status_, "ALREADY SET/UNSET");
        _verified[holder_] = status_;
    }

    function register() external payable {
        require(passholderID[_msgSender()] == 0, "ALREADY MINTED SBT");
        require(msg.value == price, "INVALID PAYMENT");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_msgSender(), tokenId);
    }

    function isPassHolder(address addr_) external view returns (bool _result) {
        _result = (passholderID[addr_] > 0);
    }

    function isVerified(address addr_) external view returns (bool _result) {
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