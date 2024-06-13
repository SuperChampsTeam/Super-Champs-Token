// SPDX-License-Identifier: None
// Super Champs Foundation 2024
pragma solidity ^0.8.24;

/// @title Base contract with important constants
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
abstract contract SCMetagameBaseDataView {
    /// @dev The key of the house id metadata tag. Used to retrieve house membership data of addresses from the metadata registry. 
    string constant HOMETOWN_ID = "hometown";

    /// @dev The key of the base multiplier metadata tag. Used to retrieve the base multiplier of addresses from the metadata registry. 
    string constant BASE_MULTIPLIER = "metagame_multiplier";
}