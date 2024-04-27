// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../../interfaces/ISCSeasonRewards.sol";

/// @title Manager for the seasonal player rewards program.
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @dev Season rewards pulled from a treasury contract that must have a token allowance set for this contract.
/// @notice Allows System Admins to set up and report scores for Seasons.
contract SCSeasonRewards is ISCSeasonRewards{

    ///@notice The protocol permissions registry
    IPermissionsManager immutable permissions;

    ///@notice The address of the rewards token. (The CHAMP token)
    IERC20 immutable token;

    ///@notice The traeasury from which Seasons pull their reward tokens.
    address treasury;

    ///@notice A list of seasons. A season's ID is its index in the list.
    ISCSeasonRewards.Season[] public seasons;

    ///@notice A mapping of scores reported for each user by address for each season by ID.
    mapping(uint256 => mapping(address => uint256)) public season_scores;

    ///@notice A mapping of quantity of tokens claimed for each user by address for each season by ID.
    mapping(uint256 => mapping(address => uint256)) public claimed_rewards;

    ///@notice A set of signatures which have already been used.
    ///@dev Member signatures are no longer valid.
    mapping(bytes => bool) private consumed_signatures;

    ///@notice A mapping of the last used signature timestamp, by user address.
    ///@dev This acts as the nonce for the signatures. Signatures with timestamps earlier than the value set are not valid.
    mapping(address => uint256) public player_last_signature_timestamp;

    ///@notice A modifier that restricts function calls to addresses with the Systems admin permission set.
    modifier isQuestSystem() {
        require(permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, msg.sender));
        _;
    }

    ///@notice A modifier that restricts function calls to addresses with the Global admin permission set.
    modifier isGlobalAdmin() {
        require(permissions.hasRole(IPermissionsManager.Role.GLOBAL_ADMIN, msg.sender));
        _;
    }

    ///@param permissions_ The address of the protocol permissions registry. Must conform to IPermissionsManager.
    ///@param token_ The address of the reward token. (The CHAMP token)
    ///@param treasury_ The address of the account/contract that the Seasons reward system pulls reward tokens from.
    constructor(address permissions_, address token_, address treasury_) {
        permissions = IPermissionsManager(permissions_);
        token = IERC20(token_);
        treasury = treasury_;
    }

    ///@notice Updates the address of the account/contract that the Seasons reward system pulls reward tokens from.
    ///@dev Only callable by Global Admins.
    ///@param treasury_ The address of the new treasury.
    function setTreasury(address treasury_) external isGlobalAdmin {
        treasury = treasury_;
    }

    ///@notice Initializes a new Season of the rewards program.
    ///@dev Only callable by Systems Admins. It is permissable to create Seasons with overlapping times.
    ///@param start_time_ The start time of the new season.
    ///@return season_ ISCSeasonRewards.Season The Season struct that was initialized.
    function startSeason(
        uint256 start_time_
    ) external isQuestSystem returns(ISCSeasonRewards.Season memory season_)
    {
        require(start_time_ > 0, "CANNOT START AT 0");
        season_.start_time = start_time_;
        season_.end_time = type(uint256).max;
        season_.id = uint32(seasons.length);
        seasons.push(season_);
    }

    ///@notice Queries the active status of a season.
    ///@param season_ The season struct to query from.
    ///@param timestamp_ The timestamp to query the active status at.
    ///@return _active bool The active status of the provided season
    function isSeasonActive(
        Season memory season_,
        uint256 timestamp_
    ) public pure returns(bool _active) 
    {
        _active = season_.end_time >= timestamp_ && timestamp_ < season_.start_time;
    }

    ///@notice Queries the finalized status of a season.
    ///@dev A season is finalized if its claim time is set.
    ///@param season_ The season struct to query from.
    ///@return _finalized bool The finalized status of the provided season.
    function isSeasonFinalized(
        Season memory season_
    ) public pure returns(bool _finalized) 
    {
        _finalized = season_.claim_end_time > 0;
    }

    ///@notice Queries if a season has ended.
    ///@param season_ The season struct to query from.
    ///@param timestamp_ The timestamp to query the ended status at.
    ///@return _ended bool True if the season has ended at the provided timestamp
    function isSeasonEnded(
        Season memory season_,
        uint256 timestamp_
    ) public pure returns(bool _ended) 
    {
        _ended = season_.end_time < timestamp_;
    }

    ///@notice Queries if a season has been finalized and can have rewards claimed from it.
    ///@param season_ The season struct to query from.
    ///@param timestamp_ The timestamp to query the ended status at.
    ///@return _active bool True if the season has ended at the provided timestamp
    function isSeasonClaimingActive(
        Season memory season_,
        uint256 timestamp_
    ) public pure returns(bool _active) 
    {
        _active = isSeasonFinalized(season_) && season_.claim_end_time >= timestamp_;
    }

    ///@notice Queries if a season has been finalized and the claim period has already elapsed.
    ///@param season_ The season struct to query from.
    ///@param timestamp_ The timestamp to query the ended status at.
    ///@return _ended bool True if the season's rewards claim period has elapsed.
    function isSeasonClaimingEnded(
        Season memory season_,
        uint256 timestamp_
    ) public pure returns(bool _ended) 
    {
        _ended = isSeasonFinalized(season_) && season_.claim_end_time < timestamp_;
    }

    ///@notice Ends a season.
    ///@dev Callable only by Systems Admins.
    ///@param id_ The id of the season to end.
    function endSeason(
        uint256 id_
    ) external isQuestSystem
    {
        Season storage _season = seasons[id_];
        require(_season.start_time > 0, "SEASON NOT FOUND");
        require(isSeasonActive(_season, block.timestamp), "SEASON NOT ACTIVE");
        _season.end_time = block.timestamp;
    }

    ///@notice Revokes unclaimed reward tokens into the treasury.
    ///@dev Callable only by Systems Admins and only after the season's claim period has elapsed.
    ///@param id_ The id of the season to end.
    function revokeUnclaimedReward(
        uint256 id_
    ) external isQuestSystem
    {
        Season storage _season = seasons[id_];
        require(_season.start_time > 0, "SEASON NOT FOUND");
        require(isSeasonClaimingEnded(_season, block.timestamp), "SEASON_CLAIM_NOT_ENDED");
        require(_season.remaining_reward_amount > 0, "ZERO_REMAINING_AMOUNT");

        bool transfer_success = token.transfer(treasury, uint256(_season.remaining_reward_amount));
        require(transfer_success, "FAILED TRANSFER");
        _season.remaining_reward_amount -= uint128(_season.remaining_reward_amount);
    }

    ///@notice Finalizes a season, setting its rewards quantity and claim period.
    ///@dev Callable only by Systems Admins and only after the season has been ended by calling the endSeason(...) function.
    ///@param id_ The id of the season to finalize.
    ///@param reward_amount_ The quantity of reward tokens to split between season participants. This quantity must be able to be transferred from the treasury.
    ///@param claim_duration_ The duration of the claim period.
    function finalize(
        uint256 id_,
        uint256 reward_amount_,
        uint256 claim_duration_
    ) external isQuestSystem
    {
        Season storage _season = seasons[id_];
        require(_season.start_time > 0, "SEASON NOT FOUND");
        require(isSeasonEnded(_season, block.timestamp), "SEASON_NOT_ENDED");
        require(!isSeasonFinalized(_season), "SEASON_FINALIZED");

        bool transfer_success = token.transferFrom(treasury, address(this), reward_amount_);
        require(transfer_success, "FAILED TRANSFER");

        _season.reward_amount = uint128(reward_amount_);
        _season.remaining_reward_amount = uint128(reward_amount_);
        _season.claim_end_time = block.timestamp + claim_duration_;
    }

    ///@notice Reports an individual player's score for the specified season.
    ///@dev Callable by anyone IF a valid signature_ is provided. Callable by Systems Admins IF signature_ is "".
    ///@param player_ The player address.
    ///@param season_id_ The ID of the season.
    ///@param score_ The player's total current score. (Current at timestamp_, if a signature is provided.
    ///@param signature_expiry_ts_ The validity time of the provided signature.  0 If being called by a systems admin.
    ///@param timestamp_ The time at which this signature was generated. 0 If being called by a systems admin.
    ///@param signature_ The signature used to test this function calls validity. "" If being called by a systems admin.
    function reportScore(
        address player_,
        uint256 season_id_,
        uint256 score_,
        uint256 signature_expiry_ts_,
        uint256 timestamp_,
        bytes memory signature_
    ) external 
    {
        Season storage _season = seasons[season_id_];
        require(_season.start_time > 0, "SEASON NOT FOUND");
        require(!isSeasonFinalized(_season), "SEASON FINALIZED");

        if(signature_.length > 0) {
            require(signature_expiry_ts_ > block.timestamp, "INVALID EXPIRY");
            require(player_last_signature_timestamp[player_] < timestamp_, "CONSUMED NONCE");
            require(!consumed_signatures[signature_], "CONSUMED SIGNATURE");
            
            player_last_signature_timestamp[player_] = timestamp_;
            consumed_signatures[signature_] = true;

            bytes32 _messageHash = keccak256(
                abi.encode(player_, season_id_, score_, signature_expiry_ts_, timestamp_));
            _messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
            
            (bytes32 _r, bytes32 _s, uint8 _v) = _splitSignature(signature_);
            address _signer = ecrecover(_messageHash, _v, _r, _s);
            require(permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, _signer), "INVALID SIGNER");
        } else {
            require(permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, msg.sender), "NOT AUTHORIZED");
        }

        _season.total_score = (_season.total_score - season_scores[season_id_][player_]) + score_;
        season_scores[season_id_][player_] = score_;
    }

    ///@notice Reports an list of players' scores for the specified season.
    ///@dev Callable only by Systems Admins.
    ///@param season_id_ The ID of the season.
    ///@param players_ The list of player addresses.
    ///@param scores_ The list of player's total current score.
    function reportScores(
        uint256 season_id_,
        address[] calldata players_,
        uint256[] calldata scores_
    ) external isQuestSystem
    {
        require(players_.length == scores_.length, "ARRAYS  MISMATCH");

        Season storage _season = seasons[season_id_];
        require(_season.start_time > 0, "SEASON NOT FOUND");
        require(!isSeasonFinalized(_season), "SEASON FINALIZED");
        
        uint256 _total_score = _season.total_score;
        for (uint256 i = 0; i < players_.length; i++) {
            _total_score = (_total_score - season_scores[season_id_][players_[i]]) + scores_[i];
            season_scores[season_id_][players_[i]] = scores_[i];
        }

        _season.total_score = _total_score;
    }

    ///@notice Claim tokens rewarded to msg.sender in the specified season.
    ///@dev Callable only on seasons which have been finalized and whose claim duration has not elapsed.
    ///@param season_id_ The season to claim reward tokens from.
    function claimReward(
        uint256 season_id_
    ) external
    {
        require(claimed_rewards[season_id_][msg.sender] == 0, "REWARD CLAIMED");

        Season storage _season = seasons[season_id_];

        require(isSeasonClaimingActive(_season, block.timestamp), "SEASON_CLAIM_ENDED");

        uint256 _score = season_scores[season_id_][msg.sender];
        uint256 _reward = (_season.reward_amount * _score) / _season.total_score;

        bool transfer_success = token.transfer(msg.sender, _reward);
        require(transfer_success, "FAILED TRANSFER");

        _season.remaining_reward_amount -= uint128(_reward);
        claimed_rewards[season_id_][msg.sender] = _reward;
    }

    ///@notice Constructs a message hash from a player score update request payload.
    ///@param player_ The player address.
    ///@param season_id_ The ID of the season.
    ///@param score_ The player's total current score. (Current at timestamp_, if a signature is provided.
    ///@param timestamp_ The time at which this signature was generated. 0 If being called by a systems admin.
    function _getMessageHash(
        address player_,
        uint256 season_id_,
        uint256 score_,
        uint256 timestamp_
    ) internal pure returns (bytes32) {
        bytes32 _messageHash =  keccak256(abi.encodePacked(player_, season_id_, score_, timestamp_));

        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
        );
    }

    /// @notice Used to split a signature into r,s,v components which are required to recover a signing address.
    /// @param sig_ The signature to split
    /// @return _r bytes32 The r component
    /// @return _s bytes32 The s component
    /// @return _v bytes32 The v component
    function _splitSignature(bytes memory sig_)
        public
        pure
        returns (bytes32 _r, bytes32 _s, uint8 _v)
    {
        require(sig_.length == 65, "invalid signature length");

        assembly {
            _r := mload(add(sig_, 32))
            _s := mload(add(sig_, 64))
            _v := byte(0, mload(add(sig_, 96)))
        }
    }

    /// @notice Transfer tokens that have been sent to this contract by mistake.
    /// @dev Only callable by address with Global Admin permissions. Cannot be called to withdraw emissions tokens.
    /// @param tokenAddress_ The address of the token to recover
    /// @param tokenAmount_ The amount of the token to recover
    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external isGlobalAdmin {
        IERC20(tokenAddress_).transfer(msg.sender, tokenAmount_);
    }
}