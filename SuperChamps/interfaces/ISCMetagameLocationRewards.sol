// SPDX-License-Identifier: None
// Super Champs 2024

pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISCMetagameLocationRewards {
    /// @param addr_ Address of the staker who needs to have their multiplier updated
    /// @notice Updates an accounts bonus multiplier from the metagame metadata system.
    /// @dev Underlying balance is assumed to be stored as a pre-multiplied quantity.
    function updateMultiplier(address addr_) external returns (uint256 _mult_bp);

    /// @param from_ Address of the staker who is spending tokens from their stake
    /// @param to_ Address of the recipient of the spent tokens
    /// @param value_ Quantity of spent tokens
    /// @notice Spends tokens directly from staked balance
    function spend(address from_, address to_, uint256 value_) external;
}