// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

/// @title Interface for protocol's seasonal player rewards program
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
interface ISCSeasonRewards {
    struct Season {
        uint256 id;
        uint256 start_time;
        uint256 end_time;
        uint256 reward_amount;
        uint256 remaining_reward_amount;
        uint256 claim_end_time;   //Last time claim is available
    }

    function startSeason(
        uint256 start_time_
    ) external returns(Season memory);

    function endSeason(
        uint256 id_
    ) external;

    function finalize(
        uint256 id_,
        uint256 reward_amount_,
        uint256 claim_duration
    ) external;


    function finalizeNative(
        uint256 id_,
        uint256 reward_amount_,
        uint256 claim_duration
    ) external payable;

    function reportRewards(
        uint256 season_id_,
        address[] calldata players_,
        uint256[] calldata rewards_
    ) external;

    function claimReward(
        uint256 season_id_
    ) external;

    function claimNativeReward(
        uint256 season_id_
    ) external;

    function getClaimableReward(
        uint256 season_id_
    ) external view returns(uint256); 

    function revokeUnclaimedReward(
        uint256 id_
    ) external;
}