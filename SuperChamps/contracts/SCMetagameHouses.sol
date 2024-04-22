// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IPermissionsManager.sol";
import "../interfaces/ISCMetagameRegistry.sol";
import "./SCMetagameHouseRewards.sol";

contract SCMetagameHouses {
    struct EpochData {
        mapping(string => uint256) house_scores;
        mapping(string => uint256) house_orders;
    }

    ISCMetagameRegistry public immutable metadata;
    IPermissionsManager public immutable permissions;
    IERC20 public immutable token;
    
    address public treasury;
    uint256 public EPOCH = 7 days;

    mapping(string => StakingRewards) public house_rewards_stakers;
    mapping(uint256 => EpochData) private epoch_data;
    string[] public houses;
    uint256[] public award_tiers_bps;

    uint256 public current_epoch = 0;
    uint256 public next_epoch = 0;

    modifier isSystemsAdmin() {
        require(permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, msg.sender));
        _;
    }

    modifier isGlobalAdmin() {
        require(permissions.hasRole(IPermissionsManager.Role.GLOBAL_ADMIN, msg.sender));
        _;
    }

    constructor(
        address permissions_,
        address token_,
        address metadata_,
        address treasury_
    ) {
        permissions = IPermissionsManager(permissions_);
        token = IERC20(token_);
        metadata = ISCMetagameRegistry(metadata_);
        treasury = treasury_;
    }

    function setTreasury(address treasury_) external isGlobalAdmin {
        treasury = treasury_;
    }

    function addHouse(string calldata house_name_) external isSystemsAdmin {
        require(address(house_rewards_stakers[house_name_]) == address(0), "HOUSE EXISTS");

        house_rewards_stakers[house_name_] = new SCMetagameHouseRewards(
            address(token),
            address(metadata),
            house_name_
        );

        houses.push(house_name_);
    }

    function getHouseRewardsStaker(string memory house_name_) public view returns (address) {
        return address(house_rewards_stakers[house_name_]);
    }

    function assignAwardTiers(uint256[] memory tiers_) external isSystemsAdmin {
        uint256 _totalBPS = 0;
        delete award_tiers_bps;

        for(uint256 i = 0 ; i < tiers_.length; i++) {
            award_tiers_bps.push(tiers_[i]);
            _totalBPS += tiers_[i];
        }

        require(_totalBPS == 1000, "DOES NOT TOTAL TO 1000 BPS");
    }

    function reportHouseScores(uint256 epoch, uint256[] memory scores_, string[] memory houses_) external isSystemsAdmin {
        require(next_epoch > block.timestamp || next_epoch == 0, "EPOCH NOT INITIALIZED");
        require(epoch == current_epoch, "REPORT FOR INCORRECT EPOCH");
        require(scores_.length == houses_.length, "MISMATHCED INPUTS");
        require(houses_.length == houses.length, "NOT A FULL REPORT");

        EpochData storage _epoch_data = epoch_data[current_epoch];

        uint256 lastScore = type(uint256).max;
        for(uint256 i = 0; i < scores_.length; i++) {
            string memory _house = houses_[i];
            require(getHouseRewardsStaker(_house) != address(0), "HOUSE DOESNT EXIST");
            require(lastScore > scores_[i], "HOUSES OUT OF ORDER");

            lastScore = scores_[i];
            _epoch_data.house_scores[_house] = lastScore;
            _epoch_data.house_orders[_house] = i + 1; //_order of 0 is used to indicate an uninitialized score. 
        }
    }

    function getHouseScoreAndOrder(uint256 epoch_, string memory house_) public view returns (uint256 score, uint256 order) {
        score = epoch_data[epoch_].house_scores[house_];
        order = epoch_data[epoch_].house_orders[house_];
    }

    function distributeRewards() external isSystemsAdmin {
        require(next_epoch <= block.timestamp, "NOT YET NEXT EPOCH");

        EpochData storage _epoch_data = epoch_data[current_epoch];
        require(award_tiers_bps.length == houses.length, "AWARD TIERS MISSING");

        uint256 _amount = token.balanceOf(treasury);
        if(_amount > token.allowance(treasury, address(this))) {
            _amount = token.allowance(treasury, address(this));
        }
        require(_amount > 0, "NOTHING TO DISTRIBUTE");
        
        bool _success = token.transferFrom(treasury, address(this), _amount);
        require(_success);
        
        uint256 _balance = token.balanceOf(address(this));
        uint256 _duration = EPOCH; //If somehow the epoch was not initialized for an entire epoch span, default to 1 EPOCH in the future
        if((next_epoch + EPOCH) > block.timestamp) {
            _duration = (next_epoch + EPOCH) - block.timestamp;
        }

        require(_balance > 0, "NOTHING TO DISTRIBUTE");
        
        bool _any_zero_order = false;
        for(uint256 i = 0; i < houses.length; i++) {
            string memory _house = houses[i];
            require(address(house_rewards_stakers[_house]) != address(0), "HOUSE DOESNT EXIST");

            uint256 _order = _epoch_data.house_orders[_house];
            uint256 _share = _balance / houses.length; //_share defaults to an even split
            if(_order > 0) { //_order is expected to be zero if the house does not have a reported score
                require(!_any_zero_order, "MISSING HOUSE SCORE");
                _share = (_balance * award_tiers_bps[_order - 1]) / 1000;
            } else if(!_any_zero_order) {  //_order of 0 is acceptable if ALL entry's _order is zero 
                require(i == 0, "MISSING HOUSE SCORE");
                _any_zero_order = true;
            }

            house_rewards_stakers[_house].setRewardsDuration(_duration);
            token.transfer(address(house_rewards_stakers[_house]), _share);
            house_rewards_stakers[_house].notifyRewardAmount(_share);
        }

        current_epoch = next_epoch;
        next_epoch = block.timestamp + _duration;
    }

    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external isSystemsAdmin {
        require(tokenAddress_ != address(token), "Cannot withdraw the staking token");
        IERC20(tokenAddress_).transfer(msg.sender, tokenAmount_);
    }

    function recoverERC20FromHouse(string calldata house_, address tokenAddress_, uint256 tokenAmount_) external isSystemsAdmin {
        house_rewards_stakers[house_].recoverERC20(tokenAddress_, tokenAmount_);
    }

    function setEpochDuration(uint256 duration_) external isSystemsAdmin {
        EPOCH = duration_;
    }

    function houseCount() public view returns (uint256 count) {
        count = houses.length;
    }
}