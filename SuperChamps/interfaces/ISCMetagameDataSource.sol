// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

/// @title Interface for views into metagame metadata
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
interface ISCMetagameDataSource {
    /// @notice Queries the bonus multiplier of a specfied address at a specified location.
    /// @param addr_ The address to query.
    /// @param location_ The location id to query.
    /// @return _result uint256 Returns the numeric metadata mapped to that address, in basis points
    function getMultiplier(address addr_, string memory location_) external view returns (uint256);

    /// @notice Queries if a specfied address is a member of a specified location.
    /// @param addr_ The address to query.
    /// @param location_ The location id to query.
    /// @return _result bool Returns true if the address is a member of the location.
    function getMembership(address addr_, string memory location_) external view returns (bool);
}