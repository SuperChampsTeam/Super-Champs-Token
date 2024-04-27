// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title An interface for Vesting escrow contracts
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @dev Solidity implementation of https://github.com/LlamaPay/yearn-vesting-escrow interface. Modified to remove un-needed functions.
interface IVestingEscrow {
    function initialize(
        address,
        address,
        address,
        uint256,
        uint256,
        uint256,
        uint256
    ) external returns(bool);

    function unclaimed() // Get the number of unclaimed, vested tokens for recipient
        external returns (uint256);

    function locked() // Get the number of locked tokens for recipient
        external returns (uint256);

    function claim(
        address beneficiary, //default to msg.sender
        uint256 amount //default to Max uint256
    ) external;

    function collect_dust( //callable by recipient to collect tokens other than the stream token, or to collect stream token dust after contract is disabled.
        address token
    ) external;
}