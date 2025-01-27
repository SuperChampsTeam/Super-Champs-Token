// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

/// @title Interface for protocol's leaderboard's player rewards program
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
interface ISCMLRewards {
    struct MemeLeaderboard {
        uint256 id;
        uint256 start_time;
        uint256 end_time;
        address[] tokens;
        uint256[] reward_amount;
        uint256[] remaining_reward_amount;
        uint256 claim_end_time;   //Last time claim is available
    }

    function startLeaderboard(
        uint256 start_time_, address[] calldata tokens
    ) external returns(MemeLeaderboard memory);

    function endLeaderboard(
        uint256 id_
    ) external;

    function finalize(
        uint256 id_,
        uint256[] calldata reward_amount_,
        uint256 claim_duration
    ) external;

    function reportRewards(
        uint256 leaderboard_id_,
        address[] calldata players_,
        uint256[][] calldata rewards_
    ) external;

    function claimReward(
        uint256 leaderboard_id_
    ) external;

    function getClaimableReward(
        uint256 leaderboard_id_
    ) external view returns(uint256); 

    function revokeUnclaimedReward(
        uint256 id_
    ) external;
}