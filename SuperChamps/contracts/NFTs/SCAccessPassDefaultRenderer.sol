// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../../interfaces/IERC721MetadataRenderer.sol";

//Single entry (semi-fungible style) Soul Bound Token metadata renderer. 
//To be replaced by custom on-chain SVG renderer eventually.
contract SCAccessPassDefaultRenderer is IERC721MetadataRenderer {
    using Strings for uint256;

    IPermissionsManager private immutable _permissions;

    string _name;
    string _symbol;
    string _uri;

    constructor(
        IPermissionsManager permissions_,
        string memory name_, 
        string memory symbol_) 
    {
        _permissions = permissions_;
        _name = name_;
        _symbol = symbol_;
    }

    modifier isSystemsAdmin() {
        require(_permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, msg.sender));
        _;
    }

    function setURI(string memory uri_) external isSystemsAdmin {
        _uri = uri_;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256) public view override returns (string memory) {
        return _uri;
    }
}