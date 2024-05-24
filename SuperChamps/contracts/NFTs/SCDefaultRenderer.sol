// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../../interfaces/IERC721MetadataRenderer.sol";
import "../../interfaces/ISCAccessPass.sol";

/// @title Single entry (semi-fungible style) Soul Bound Token metadata renderer. 
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @dev Conforms to subset of IERC721Metadata. Able to be replaced by a custom on-chain SVG renderer.
contract SCDefaultRenderer is IERC721MetadataRenderer {
    using Strings for uint256;

    ///@notice The permissions registry
    IPermissionsManager private immutable _permissions;

    ///@notice The access pass SBT contract
    ISCAccessPass private _access_pass; 

    ///@notice The name which is returned by the name() function.
    string _name;

    ///@notice The symbol which is returned by the symbol() function.
    string _symbol;

    ///@notice The name which is returned by the name() function.
    string _uri;

    ///@notice Toggle that switches to render using concatenated token IDs.
    bool _concatenate_ids;

    ///@notice A function modifier that restrics calls to addresses with the Systems Admin permission set.
    modifier isSystemsAdmin() {
        require(_permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, msg.sender));
        _;
    }

    ///@param permissions_ The protocol permissions registry
    ///@param name_ The name of the NFT collection associated with this renderer.
    ///@param symbol_ The symbol of the NFT collection associated with this renderer.
    constructor(
        IPermissionsManager permissions_,
        ISCAccessPass access_pass_,
        string memory name_, 
        string memory symbol_,
        string memory uri_) 
    {
        _permissions = permissions_;
        _access_pass = access_pass_;
        _name = name_;
        _symbol = symbol_;
        _uri = uri_;
    }    

    ///@notice Sets the URI to return from the tokenURI() function.
    ///@dev Only callable by a Systems Admin.
    ///@param uri_ The new URI to return.
    ///@param concatenate_ids_ Whether or not to concatenate token IDs to the end of the base uri_
    function setURI(string memory uri_, bool concatenate_ids_) external isSystemsAdmin {
        _uri = uri_;
        _concatenate_ids = concatenate_ids_;
    }

    ///@notice Sets the contract address that pass level is read from.
    ///@dev Only callable by a Systems Admin.
    ///@param access_pass_ The contract address
    function setAccessPass(address access_pass_) external isSystemsAdmin {
        _access_pass = ISCAccessPass(access_pass_);
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
    function tokenURI(uint256 token_id_) public view override returns (string memory) {
        if(_concatenate_ids) 
        {
            return bytes(_uri).length > 0 ? string.concat(_uri, token_id_.toString()) : "";
        } 
        else 
        {
            uint256 _level = _access_pass.getLevel(token_id_);
            return string.concat(_uri, string.concat("/",_level.toString()));
        }
    }
}