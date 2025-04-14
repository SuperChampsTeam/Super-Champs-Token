// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Metagame staking pool interface
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice Interface for staking pool for Super Champ tokens metagame.
interface ISCMetagamePool{
    event Stake(address staker, address source, uint256 amount, uint256 balance);
    event Unstake(address staker, uint256 amount, uint256 balance);
    event SpendFromStake(address staker, address source, uint256 amount, uint256 balance, address receiver, string data);

    error UnableToTransferTokens(address staker, uint256 amount);
    error UnableToUnstakeTokens(address staker, uint256 amount, uint256 total_staked_supply);
    error UnexpectedBalance();

    function stake(uint256 amount_) external;
    function stakeNative(uint256 amount_) external payable;
    function stakeFor(address staker_, uint256 amount_) external;
    function stakeNativeFor(address staker_, uint256 amount_) external payable;
    function approve(address spender_, uint256 amount_) external;
    function spend(uint256 amount_, address staker_, address receiver_, string memory data_) external;
    function unstake(uint256 amount_) external;
}