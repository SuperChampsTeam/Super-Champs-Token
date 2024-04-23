// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IPermissionsManager.sol";
import "../interfaces/ISCSeasonRewards.sol";

contract SCSeasonRewards is ISCSeasonRewards{

    uint32 constant MIN_CLAIM_BUFFER = 10 minutes;

    IPermissionsManager immutable permissions;
    IERC20 immutable token;
    address treasury;

    ISCSeasonRewards.Season[] public seasons;
    mapping(uint256 => mapping(address => uint256)) public season_scores;
    mapping(uint256 => mapping(address => uint256)) public claimed_rewards;

    mapping(bytes => bool) private consumed_signatures;
    mapping(address => uint256) public player_last_signature_timestamp;
    

    bool _reentrancy_locked;
    modifier nonreentrant {
        require(!_reentrancy_locked);
        _reentrancy_locked = true;
        _;
        _reentrancy_locked = false; 
    }

    modifier isQuestSystem() {
        require(permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, msg.sender));
        _;
    }

    modifier isGlobalAdmin() {
        require(permissions.hasRole(IPermissionsManager.Role.GLOBAL_ADMIN, msg.sender));
        _;
    }

    constructor(address permissions_, address token_, address treasury_) {
        permissions = IPermissionsManager(permissions_);
        token = IERC20(token_);
        treasury = treasury_;
    }

    function setTreasury(address treasury_) external isGlobalAdmin {
        treasury = treasury_;
    }

    function startSeason(
        uint256 start_time_
    ) external isQuestSystem nonreentrant returns(ISCSeasonRewards.Season memory season_)
    {
        require(start_time_ > 0, "CANNOT START AT 0");
        season_.start_time = start_time_;
        season_.end_time = type(uint256).max;
        season_.id = uint32(seasons.length);
        seasons.push(season_);
    }

    function isSeasonActive(
        Season memory season_,
        uint256 timestamp
    ) public pure returns(bool _active) 
    {
        _active = season_.end_time >= timestamp && timestamp >= season_.start_time;
    }

    function isSeasonFinalized(
        Season memory season_
    ) public pure returns(bool _active) 
    {
        _active = season_.claim_end_time > 0;
    }

    function isSeasonEnded(
        Season memory season_,
        uint256 timestamp
    ) public pure returns(bool _ended) 
    {
        _ended = season_.end_time < timestamp;
    }

    function isSeasonClaimingActive(
        Season memory season_,
        uint256 timestamp
    ) public pure returns(bool _ended) 
    {
        _ended = isSeasonFinalized(season_) && season_.claim_end_time >= timestamp;
    }

    function isSeasonClaimingEnded(
        Season memory season_,
        uint256 timestamp
    ) public pure returns(bool _ended) 
    {
        _ended = isSeasonFinalized(season_) && season_.claim_end_time < timestamp;
    }

    function endSeason(
        uint256 id_
    ) external isQuestSystem
    {
        Season storage _season = seasons[id_];
        require(_season.start_time > 0, "SEASON NOT FOUND");
        require(isSeasonActive(_season, block.timestamp), "SEASON NOT ACTIVE");
        _season.end_time = block.timestamp;
    }

    function revokeUnclaimedReward(
        uint256 id_
    ) external isQuestSystem nonreentrant
    {
        Season storage _season = seasons[id_];
        require(_season.start_time > 0, "SEASON NOT FOUND");
        require(isSeasonClaimingEnded(_season, block.timestamp), "SEASON_CLAIM_NOT_ENDED");
        require(_season.remaining_reward_amount > 0, "ZERO_REMAINING_AMOUNT");

        bool transfer_success = token.transfer(treasury, uint256(_season.remaining_reward_amount));
        require(transfer_success, "FAILED TRANSFER");
        _season.remaining_reward_amount -= uint128(_season.remaining_reward_amount);
    }

    function finalize(
        uint256 id_,
        uint256 reward_amount_,
        uint256 claim_duration
    ) external isQuestSystem nonreentrant
    {
        Season storage _season = seasons[id_];
        require(_season.start_time > 0, "SEASON NOT FOUND");
        require(isSeasonEnded(_season, block.timestamp), "SEASON_NOT_ENDED");
        require(!isSeasonFinalized(_season), "SEASON_FINALIZED");

        bool transfer_success = token.transferFrom(treasury, address(this), reward_amount_);
        require(transfer_success, "FAILED TRANSFER");

        _season.reward_amount = uint128(reward_amount_);
        _season.remaining_reward_amount = uint128(reward_amount_);
        _season.claim_end_time = block.timestamp + claim_duration;
    }

    function reportScore(
        address player_,
        uint256 season_id_,
        uint256 score_,
        uint256 signature_expiry_ts_,
        uint256 timestamp_,
        bytes memory signature_
    ) external 
    {
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

        Season storage _season = seasons[season_id_];
        require(_season.start_time > 0, "SEASON NOT FOUND");
        require(!isSeasonFinalized(_season), "SEASON FINALIZED");

        _season.total_score = (_season.total_score - season_scores[season_id_][player_]) + score_;
        season_scores[season_id_][player_] = score_;
    }

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

    function claimReward(
        uint256 season_id_
    ) external nonreentrant
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
}