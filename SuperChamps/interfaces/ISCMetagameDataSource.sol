// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "./ISCMetagameRegistry.sol";

/// @title Interface for views into metagame metadata
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
interface ISCMetagameDataSource {
    function metadata_registry() external view returns (ISCMetagameRegistry);

    /// @notice Sets the bonus multiplier for this data source
    /// @param addr_ The address to set multiplier for
    function setMultiplier(address addr_, uint256 multiplier_bonus_) external;

    /// @notice Queries the bonus multiplier for this data source
    /// @param addr_ The address to query.
    /// @return _result uint256 Returns the numeric metadata mapped to this data source, in basis points
    function getMultiplier(address addr_) external view returns (uint256);

    /// @notice Queries the total multiplier for the associated location
    /// @param addr_ The address to query
    /// @dev Minimum return value should be 100% ie. 10,000
    /// @return _result uint256 Returns the total multiplier, in basis points.
    function getTotalMultiplier(address addr_) external view returns (uint256);

    /// @notice Queries if a specfied address is a member of a specified location.
    /// @param addr_ The address to query.
    /// @param location_ The location id to query.
    /// @return _result bool Returns true if the address is a member of the location.
    function getMembership(address addr_, string memory location_) external view returns (bool);
}