// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/// @title IKiguMinter - Interface for the MinterUpgradeable contract
interface IKiguMinter {
    function mintKiguToken() external returns (uint);

}
