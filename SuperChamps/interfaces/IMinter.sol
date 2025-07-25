// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

/// @title IMinter - Interface for the MinterUpgradeable contract
interface IMinter {
    function updatePeriod() external returns (uint);

    function mintInitialSupply() external;

    function setDistributionWallets(address[4] calldata wallets) external;

    function setDistributionPercents(uint256[4] calldata percents) external;
}
