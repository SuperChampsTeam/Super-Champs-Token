// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

interface ISCSeasonRewards {
    struct Season {
        uint256 id;
        uint256 start_time;
        uint256 end_time;
        uint256 reward_amount;
        uint256 remaining_reward_amount;
        uint256 total_score;
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

    function reportScore(
        address player_,
        uint256 season_id_,
        uint256 score_,
        uint256 signature_expiry_ts_,
        uint256 timestamp_,
        bytes memory signature_
    ) external;

    function reportScores(
        uint256 season_id_,
        address[] calldata players_,
        uint256[] calldata scores_
    ) external;

    function claimReward(
        uint256 season_id_
    ) external;

    function revokeUnclaimedReward(
        uint256 id_
    ) external;
}