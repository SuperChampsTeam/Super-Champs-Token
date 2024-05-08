// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PermissionsManager.sol";
import "../Token/ExponentialVestingEscrow.sol";
import "../Token/SuperChampsToken.sol";

/// @title A deployment helper contract which simplifies the entire initial protocol setup.
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice Protocol setup and Token generation are simplified to the deployment of a single contract. 
/// @dev Additionally contains a function that simplifies the creation of emissions pools.
contract SCDeploymentHelper {
    
    //(success, ) = abi.encodeWithSelector(bytes4(keccak256("myfunction(uint256,uint256)")), 400,500)
}