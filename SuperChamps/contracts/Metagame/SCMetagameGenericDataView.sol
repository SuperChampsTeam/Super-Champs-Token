// SPDX-License-Identifier: None
// Super Champs Foundation 2024
pragma solidity ^0.8.24;


import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../Utils/SCPermissionedAccess.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../../interfaces/ISCMetagameRegistry.sol";
import "../../interfaces/ISCMetagameDataSource.sol";
import "../../interfaces/ISCAccessPass.sol";

/// @title Metagame data view for determining metagame multipliers and membership, by address
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
abstract contract SCMetagameGenericDataView is ISCMetagameDataSource, SCPermissionedAccess {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev The key of the house id metadata tag. Used to retrieve house membership data of addresses from the metadata registry. 
    string constant HOMETOWN_ID = "hometown";

    /// @dev The key of the base multiplier metadata tag. Used to retrieve the base multiplier of addresses from the metadata registry. 
    string constant BASE_MULTIPLIER = "metagame_multiplier";

    ISCMetagameRegistry public metadata_registry;
    EnumerableSet.AddressSet private additional_data_modules;

    event UpdatedLocationMetadataView(string location, address metadata_view);
    event HometownSet(string user_, string location_);

    constructor(address permissions_, address metadata_registry_) SCPermissionedAccess(permissions_) {
        metadata_registry = ISCMetagameRegistry(metadata_registry_);
    }

    /// @notice Gets the ISCMetagameDataSource view for a specified location.
    /// @param location_ The location id.
    /// @return view_ The queried data source.
    function getLocationView(string memory location_) virtual view internal returns (ISCMetagameDataSource view_);

    /// @notice Called by the staking contract to inform on staking activity
    function informStake(address user) public virtual;

    /// @notice Queries the global multiplier bonus of a specfied address.
    /// @param addr_ The address to query.
    /// @return _result uint256 Returns the numeric metadata mapped to that address, in basis points. 
    /// @dev Global bonus multiplier is added to 100% (10_000) to determine multiplier.
    function getMultiplier(address addr_) public view virtual returns (uint256) {
        return metadata_registry.metadataUInt(addr_, BASE_MULTIPLIER);
    }

    function addDataSourceModule(address additional_data_module_) public isSystemsAdmin {
        additional_data_modules.add(additional_data_module_);
    }

    function removeDataSourceModule(address additional_data_module_) public isSystemsAdmin {
        additional_data_modules.remove(additional_data_module_);
    }

    /// @notice Returns the total bonus multiplier of a specfied address
    /// @param addr_ The address to query
    /// @return _multiplier_ uint256 Returns the numeric metadata mapped to that address, in basis points
    function getTotalMultiplier(address addr_) external view returns (uint256 _multiplier_) {
        uint256 _length = additional_data_modules.length();
        for(uint256 i; i < _length; i++) {
            ISCMetagameDataSource _data_source = ISCMetagameDataSource(additional_data_modules.at(i));
            _multiplier_ += _data_source.getMultiplier(addr_);
        }

        _multiplier_ += 10_000 + getMultiplier(addr_);
    }

    /// @notice Sets a user's "hometown" location
    /// @param uid_ The user to update
    /// @param location_ The new hometown location name
    /// @dev Only callable by Systems Admin
    function setHometown(string memory uid_, string memory location_) external isSystemsAdmin {
        metadata_registry.setMetadata(uid_, HOMETOWN_ID, location_);
        emit HometownSet(uid_, location_);
    }

    /// @notice Queries if a specfied address is a member of a specified location.
    /// @param addr_ The address to query.
    /// @param location_ The location id to query.
    /// @return bool Returns true if the address is a member of the location.
    function getMembership(address addr_, string memory location_) external view returns (bool) {
        if( keccak256(bytes(metadata_registry.metadataString(addr_, HOMETOWN_ID))) == 
            keccak256(bytes(location_)))
        {
            return true;
        }

        uint256 _length = additional_data_modules.length();
        for(uint256 i; i < _length; i++) {
            ISCMetagameDataSource _data_source = ISCMetagameDataSource(additional_data_modules.at(i));
            if(_data_source.getMembership(addr_, location_)) {
                return true;
            }
        }

        return false;
    }
}