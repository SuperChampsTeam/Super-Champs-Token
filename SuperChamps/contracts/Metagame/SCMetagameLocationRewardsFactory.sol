// SPDX-License-Identifier: None
// Super Champs Foundation 2024
pragma solidity ^0.8.24;

import "../../interfaces/ISCMetagameLocationRewardsFactory.sol";
import "./SCMetagameLocationRewards.sol";

/// @title Manager for "Location Cup" token metagame
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice Allows system to add locations, report scores for locations, assign awards tier percentages and distribute emissions tokens to location contribution contracts.
contract SCMetagameLocationRewardsFactory is ISCMetagameLocationRewardsFactory{
    /// @notice Add a new "Location" to the metagame system.
    /// @dev This creates a new contract which participants can contribute tokens to. This new entity is bound to one of the possible "Locations" that the participants accounts can belong to.
    /// @param location_name_ A name for the new "Location". Must be the same string used by the metadata registry system.
    function addLocation(
        string calldata location_name_,
        address token,
        address permissions,
        address staking_manager,
        address access_pass
    ) external returns (address location) {
        location = address(new SCMetagameLocationRewards(
            token,
            permissions,
            staking_manager,
            location_name_,
            access_pass
        ));
    }
}
