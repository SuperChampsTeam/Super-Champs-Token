// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

/// @title Interface for metagame staking factory
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
interface ISCMetagameLocationRewardsFactory {
    /// @notice Add a new "Location" to the metagame system.
    /// @param location_name_ A name for the new "Location". Must be the same string used by the metadata registry system.
    function addLocation(
        string calldata location_name_,
        address token,
        address permissions,
        address staking_manager,
        address access_pass
    ) external returns (address location);
}