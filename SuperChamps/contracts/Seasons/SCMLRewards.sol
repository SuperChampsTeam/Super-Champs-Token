// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Utils/SCPermissionedAccess.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../../interfaces/ISCMLRewards.sol";

/// @title Manager for the meme leaderboard player rewards program.
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
contract SCMLRewards is ISCMLRewards, SCPermissionedAccess {
    ///@notice The treasury from which meme leaderboards pull their reward tokens.
    address public treasury;

    ///@notice A list of Meme Leaderboards (MemeLeaderboard). A leaderboard's ID is its index in the list.
    MemeLeaderboard[] public memeLeaderboards;

    ///@notice A mapping of rewards reported for each user by address for each leaderboard by ID and token.
    mapping(uint256 => mapping(address => mapping(address => uint256)))
        public leaderboard_rewards;

    ///@notice A mapping of quantity of tokens claimed for each user by address for each leaderboard by ID and token.
    mapping(uint256 => mapping(address => mapping(address => uint256)))
        public claimed_rewards;

    event TreasurySet(address treasury);
    event LeaderboardStarted(
        uint256 leaderboardId,
        uint256 startTime,
        address[] tokens
    );
    event LeaderboardFinalized(
        uint256 leaderboardId,
        uint256[] rewardAmounts,
        uint256 claimEndTime
    );
    event RewardsClaimed(
        uint256 leaderboardId,
        address player,
        address token,
        uint256 amount
    );
    event DebugStartSeason(uint256 start_time, address[] tokens);
    event Debug(string message, uint256 value);
    event DebugAddress(string message, address value);

    constructor(address permissions_, address treasury_)
        SCPermissionedAccess(permissions_)
    {
        treasury = treasury_;
    }

    function startLeaderboard(uint256 start_time_, address[] calldata tokens_)
        external
        isSystemsAdmin
        returns ( uint256 id, uint256 start_time, uint256 end_time, address[] calldata tokens )
    {
        emit Debug("Start Time", start_time_);
        emit Debug("Tokens Length", tokens_.length);
        
        require(start_time_ > 0, "CANNOT START AT 0");
        require(tokens_.length > 0, "NO TOKENS PROVIDED");
        require(tokens_.length <= 100, "TOO MANY TOKENS"); // Example limit


        for (uint256 i = 0; i < tokens_.length; i++) {
            require(tokens_[i] != address(0), "INVALID TOKEN ADDRESS");
            emit DebugAddress("Token Address", tokens_[i]);
        }

        uint256 leaderboardId = memeLeaderboards.length;
        memeLeaderboards.push(); // Add a new empty leaderboard
        MemeLeaderboard storage leaderboard = memeLeaderboards[leaderboardId];

        leaderboard.id = leaderboardId;
        leaderboard.start_time = start_time_;
        leaderboard.end_time = type(uint256).max;
        leaderboard.tokens = new address[](tokens_.length);
        for (uint256 i = 0; i < tokens_.length; i++) {
            leaderboard.tokens[i] = tokens_[i];
        }
        leaderboard.reward_amount = new uint256[](tokens_.length);
        leaderboard.remaining_reward_amount = new uint256[](tokens_.length);

        emit LeaderboardStarted(
            leaderboard.id,
            leaderboard.start_time,
            leaderboard.tokens
        );
        emit Debug("Leaderboard ID", leaderboard.id);

        return (
            leaderboard.id,
            leaderboard.start_time,
            leaderboard.end_time,
            tokens_
        );
    }

    function endLeaderboard(uint256 id_) external isSystemsAdmin {
        MemeLeaderboard storage leaderboard = memeLeaderboards[id_];
        require(leaderboard.start_time > 0, "LEADERBOARD NOT FOUND");
        require(
            leaderboard.end_time == type(uint256).max,
            "LEADERBOARD ALREADY ENDED"
        );
        leaderboard.end_time = block.timestamp;
    }

    function finalize(
        uint256 id_,
        uint256[] calldata reward_amount_,
        uint256 claim_duration
    ) external isSystemsAdmin {
        MemeLeaderboard storage leaderboard = memeLeaderboards[id_];
        require(leaderboard.start_time > 0, "LEADERBOARD NOT FOUND");
        require(
            leaderboard.end_time < block.timestamp,
            "LEADERBOARD NOT ENDED"
        );
        require(leaderboard.claim_end_time == 0, "LEADERBOARD FINALIZED");
        require(
            reward_amount_.length == leaderboard.tokens.length,
            "ARRAY MISMATCH"
        );

        for (uint256 i = 0; i < leaderboard.tokens.length; i++) {
            IERC20 token = IERC20(leaderboard.tokens[i]);
            require(
                token.transferFrom(treasury, address(this), reward_amount_[i]),
                "FAILED TRANSFER"
            );
            leaderboard.reward_amount[i] = reward_amount_[i];
            leaderboard.remaining_reward_amount[i] = reward_amount_[i];
        }
        leaderboard.claim_end_time = block.timestamp + claim_duration;
        emit LeaderboardFinalized(
            id_,
            reward_amount_,
            leaderboard.claim_end_time
        );
    }

    function reportRewards(
        uint256 leaderboard_id_,
        address[] calldata players_,
        uint256[][] calldata rewards_
    ) external isSystemsAdmin {
        MemeLeaderboard storage leaderboard = memeLeaderboards[leaderboard_id_];
        require(leaderboard.start_time > 0, "LEADERBOARD NOT FOUND");
        require(players_.length == rewards_.length, "ARRAYS MISMATCH");
        require(
            rewards_[0].length == leaderboard.tokens.length,
            "TOKEN ARRAY MISMATCH"
        );

        for (uint256 i = 0; i < players_.length; i++) {
            for (uint256 j = 0; j < leaderboard.tokens.length; j++) {
                leaderboard_rewards[leaderboard_id_][players_[i]][
                    leaderboard.tokens[j]
                ] = rewards_[i][j];
            }
        }
    }

    function claimReward(uint256 leaderboard_id_) external {
        MemeLeaderboard storage leaderboard = memeLeaderboards[leaderboard_id_];
        require(
            leaderboard.claim_end_time >= block.timestamp,
            "CLAIM PERIOD ENDED"
        );

        for (uint256 i = 0; i < leaderboard.tokens.length; i++) {
            address token = leaderboard.tokens[i];
            uint256 reward = leaderboard_rewards[leaderboard_id_][msg.sender][
                token
            ];
            require(reward > 0, "NO REWARD");
            require(
                claimed_rewards[leaderboard_id_][msg.sender][token] == 0,
                "ALREADY CLAIMED"
            );
            claimed_rewards[leaderboard_id_][msg.sender][token] = reward;
            leaderboard.remaining_reward_amount[i] -= reward;
            require(
                IERC20(token).transfer(msg.sender, reward),
                "TRANSFER FAILED"
            );
            emit RewardsClaimed(leaderboard_id_, msg.sender, token, reward);
        }
    }

    function getClaimableReward(uint256 leaderboard_id_)
        external
        view
        returns (uint256)
    {
        MemeLeaderboard storage leaderboard = memeLeaderboards[leaderboard_id_];
        uint256 totalReward;
        for (uint256 i = 0; i < leaderboard.tokens.length; i++) {
            totalReward += leaderboard_rewards[leaderboard_id_][msg.sender][
                leaderboard.tokens[i]
            ];
        }
        return totalReward;
    }

    function revokeUnclaimedReward(uint256 id_) external isSystemsAdmin {
        MemeLeaderboard storage leaderboard = memeLeaderboards[id_];
        require(
            leaderboard.claim_end_time < block.timestamp,
            "CLAIM PERIOD NOT ENDED"
        );
        for (uint256 i = 0; i < leaderboard.tokens.length; i++) {
            uint256 remaining = leaderboard.remaining_reward_amount[i];
            if (remaining > 0) {
                require(
                    IERC20(leaderboard.tokens[i]).transfer(treasury, remaining),
                    "TRANSFER FAILED"
                );
                leaderboard.remaining_reward_amount[i] = 0;
            }
        }
    }
}
