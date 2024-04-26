// SPDX-License-Identifier: None
// Joyride Games 2024
pragma solidity ^0.8.24;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../../interfaces/ISCMetagameRegistry.sol";
import "./SCMetagameHouseRewards.sol";

/// @title Manager for "House Cup" token metagame
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice Allows system to add houses, report scores for houses, assign awards tier percentages and distribute emissions tokens to house contribution contracts.
contract SCMetagameHouses {

    /// @notice Stores data related to each epoch of the house cup metagame
    struct EpochData {
        /// @notice Maps names of houses to their score
        mapping(string => uint256) house_scores;
        /// @notice Maps names of houses to their rank order
        /// @dev Order of 0 is used to indicate an uninitialized score. "1" is top score rank order.
        mapping(string => uint256) house_orders;
    }

    /// @notice The metadata registry.
    /// @dev Stores house membership information for users.
    ISCMetagameRegistry public immutable metadata;

    /// @notice The permissions registry.
    IPermissionsManager public immutable permissions;

    /// @notice The emissions token.
    IERC20 public immutable token;
    
    /// @notice The treasury that this contract pulls emissions tokens from.
    /// @dev An allowance must be set on the emissions token contract that permits this contract access to the treasury's tokens.
    address public treasury;

    /// @notice The duration of the emissions epochs.
    uint256 public EPOCH = 7 days;

    /// @notice A mapping of the emissions contribution contracts by house name
    mapping(string => SCMetagameHouseRewards) public house_rewards;
    
    /// @notice List of the existant house names
    string[] public houses;

    /// @notice List of award tiers, measured in proportional basis points
    /// @dev The top scoring house receives prorata share of emissions from entry 0
    uint256[] public award_tiers_bps;

    /// @notice Mapping of epoch state information by epoch number
    mapping(uint256 => EpochData) private epoch_data;

    /// @notice The numeric id (start timestamp) of the current epoch
    uint256 public current_epoch = 0;

    /// @notice The numeric id (start timestamp) of the next epoch 
    uint256 public next_epoch = 0;

    /// @notice Function modifier which requires the sender to possess the systems admin permission as recorded in "permissions"
    modifier isSystemsAdmin() {
        require(permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, msg.sender));
        _;
    }

    /// @notice Function modifier which requires the sender to possess the global admin permission as recorded in "permissions"
    modifier isGlobalAdmin() {
        require(permissions.hasRole(IPermissionsManager.Role.GLOBAL_ADMIN, msg.sender));
        _;
    }

    /// @param permissions_ Address of the protocol permissions registry. Must conform to IPermissionsManager.
    /// @param token_ Address of the emissions token.
    /// @param metadata_ Address of the protocol metadata registry. Must conform to ISCMetagameRegistry.
    /// @param treasury_ Address of the treasury which holds emissions tokens for use by the House Cup metagame.
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

    /// @notice Assigns a new treasury from which the metagame system draws token rewards.
    /// @dev Only callable by address with Global Admin permissions. Ability to withdraw tokens from treasury_ must be set separately.
    /// @param treasury_ The new treasury's address. 
    function setTreasury(address treasury_) external isGlobalAdmin {
        treasury = treasury_;
    }

    /// @notice Add a new "House" to the metagame system.
    /// @dev Only callable by address with System Admin permissions. This creates a new contract which participants can contribute tokens to. This new entity is bound to one of the possible "Houses" that the participants accounts can belong to.
    /// @param house_name_ A name for the new "House". Must be the same string used by the metadata registry system.
    function addHouse(string calldata house_name_) external isSystemsAdmin {
        require(address(house_rewards[house_name_]) == address(0), "HOUSE EXISTS");

        house_rewards[house_name_] = new SCMetagameHouseRewards(
            address(token),
            address(metadata),
            house_name_
        );

        houses.push(house_name_);
    }

    /// @notice Retreives the address of the contribution repository of the specified "House".
    /// @param house_name_ The name of the "House". Must be the same string used by the metadata registry system.
    function getHouseRewardsStaker(string memory house_name_) public view returns (address) {
        return address(house_rewards[house_name_]);
    }

    /// @notice Assigns reward tiers for houses. Awards will be based on house rank each epoch.
    /// @dev Only callable by address with System Admin permissions.
    /// @param tiers_ List of award tiers, in basis points. Length must match the quantity of houses. Total of all tiers must equal 1000.
    function assignAwardTiers(uint256[] memory tiers_) external isSystemsAdmin {
        require(tiers_.length == houses.length, "AWARD TIERS MISMATCH");

        uint256 _totalBPS = 0;
        delete award_tiers_bps;

        for(uint256 i = 0 ; i < tiers_.length; i++) {
            award_tiers_bps.push(tiers_[i]);
            _totalBPS += tiers_[i];
        }

        require(_totalBPS == 1000, "DOES NOT TOTAL TO 1000 BPS");
    }

    /// @notice Report the scores for each house for the 
    /// @dev Only callable by address with System Admin permissions. Overwrites previous score reports for current epoch. Must report scores for each existant house.
    /// @param epoch_ The epoch the report is for
    /// @param scores_ List of score values in descending order
    /// @param houses_ List of houses that correspond to the list of scores_
    function reportHouseScores(uint256 epoch_, uint256[] memory scores_, string[] memory houses_) external isSystemsAdmin {
        require(epoch_ == current_epoch, "REPORT FOR INCORRECT EPOCH");
        require(scores_.length == houses_.length, "MISMATHCED INPUTS");
        require(houses_.length == houses.length, "NOT A FULL REPORT");

        EpochData storage _epoch_data = epoch_data[current_epoch];

        uint256 _lastScore = type(uint256).max;
        for(uint256 i = 0; i < scores_.length; i++) {
            string memory _house = houses_[i];
            require(getHouseRewardsStaker(_house) != address(0), "HOUSE DOESNT EXIST");
            require(_lastScore > scores_[i], "HOUSES OUT OF ORDER");

            _lastScore = scores_[i];
            _epoch_data.house_scores[_house] = _lastScore;
            _epoch_data.house_orders[_house] = i + 1; //_order of 0 is used to indicate an uninitialized score. 
        }
    }

    /// @notice Retrieves the score and rank order of a specified house for a given epoch. 
    /// @param epoch_ The epoch the request is for
    /// @param house_ The house the request is for
    function getHouseScoreAndOrder(uint256 epoch_, string memory house_) public view returns (uint256 score, uint256 order) {
        score = epoch_data[epoch_].house_scores[house_];
        order = epoch_data[epoch_].house_orders[house_];
    }

    /// @notice Distribute emissions tokens to each houses contributions contract and initializes the next epoch.
    /// @dev Only callable by address with System Admin permissions. Must be called after the epoch has elapsed. Must be called after a score report is generated for each house (or no houses for equal split). Pulls as many tokens as able from the treasury to split between house contribution emissions contracts.
    function distributeRewards() external isSystemsAdmin {
        require(next_epoch <= block.timestamp, "NOT YET NEXT EPOCH");

        EpochData storage _epoch_data = epoch_data[current_epoch];
        require(award_tiers_bps.length == houses.length, "AWARD TIERS MISMATCH");

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
            require(address(house_rewards[_house]) != address(0), "HOUSE DOESNT EXIST");

            uint256 _order = _epoch_data.house_orders[_house];
            uint256 _share = _balance / houses.length; //_share defaults to an even split
            if(_order > 0) { //_order is expected to be zero if the house does not have a reported score
                require(!_any_zero_order, "MISSING HOUSE SCORE");
                _share = (_balance * award_tiers_bps[_order - 1]) / 1000;
            } else if(!_any_zero_order) {  //_order of 0 is acceptable if ALL entry's _order is zero 
                require(i == 0, "MISSING HOUSE SCORE");
                _any_zero_order = true;
            }

            house_rewards[_house].setRewardsDuration(_duration);
            token.transfer(address(house_rewards[_house]), _share);
            house_rewards[_house].notifyRewardAmount(_share);
        }

        current_epoch = next_epoch;
        next_epoch = block.timestamp + _duration;
    }

    /// @notice Transfer tokens that have been sent to this contract by mistake.
    /// @dev Only callable by address with Global Admin permissions. Cannot be called to withdraw emissions tokens.
    /// @param tokenAddress_ The address of the token to recover
    /// @param tokenAmount_ The amount of the token to recover
    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external isGlobalAdmin {
        require(tokenAddress_ != address(token), "Cannot withdraw the emissions token");
        IERC20(tokenAddress_).transfer(msg.sender, tokenAmount_);
    }

    /// @notice Transfer tokens that have been sent to a house staking contract by mistake.
    /// @dev Only callable by address with Global Admin permissions. Cannot be called to withdraw emissions tokens.
    /// @param house_ The house name of the contract to recover tokens from
    /// @param tokenAddress_ The address of the token to recover
    /// @param tokenAmount_ The amount of the token to recover
    function recoverERC20FromHouse(string calldata house_, address tokenAddress_, uint256 tokenAmount_) external isGlobalAdmin {
        house_rewards[house_].recoverERC20(tokenAddress_, tokenAmount_);
    }

    /// @notice Set a new duration for subsequent epochs
    /// @dev Only callable by address with Systems Admin permissions. 
    /// @param duration_ The new duration in seconds
    function setEpochDuration(uint256 duration_) external isSystemsAdmin {
        EPOCH = duration_;
    }

    /// @notice Read the quantity of houses that exist
    function houseCount() public view returns (uint256 count) {
        count = houses.length;
    }
}