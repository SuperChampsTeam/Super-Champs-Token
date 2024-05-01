// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

/// @title Interface for protocol metagame metadata registry
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
interface ISCAccessPass {
    /// @notice Queries if a specfied address has minted an SBT.
    /// @param addr_ The address to query.
    /// @return _result bool Returns true if the address has minted an SBT .
    function isPassHolder(address addr_) external view returns (bool);

    /// @notice Queries if a specfied address has been verified.
    /// @param addr_ The address to query.
    /// @return _result bool Returns true if the address has had its verification status set to true.
    function isVerified(address addr_) external view returns (bool);
}