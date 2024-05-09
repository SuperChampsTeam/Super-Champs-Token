// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "./IPermissionsManager.sol";

/// @title Interface which allows contracts to reference lock state and permissions manager from the CHAMP token.
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
interface ISuperChampsToken {
    ///@notice The protocol permissions registry
    function permissions() external returns (IPermissionsManager);

    ///@notice A toggle that indicates if transfers are locked to Transfer Admins. Once this toggle is set to true, it cannot be unset.
    function transfersLocked() external returns (bool); 
}