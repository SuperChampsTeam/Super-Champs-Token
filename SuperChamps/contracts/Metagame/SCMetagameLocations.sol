// SPDX-License-Identifier: None
// Super Champs Foundation 2024
pragma solidity ^0.8.24;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "../../../Synthetix/contracts/interfaces/IStakingRewards.sol";
import "../Utils/SCPermissionedAccess.sol";
import "../../interfaces/ISCMetagameLocationRewardsFactory.sol";
import "../../interfaces/ISCMetagameLocationRewards.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../../interfaces/ISCMetagameRegistry.sol";
import "../../interfaces/ISCMetagameDataSource.sol";
import "../../interfaces/ISCAccessPass.sol";
import "./SCMetagameLocationRewards.sol";
import "./SCMetagameGenericDataView.sol";

/// @title Manager for "Location Cup" token metagame
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice Allows system to add locations, report scores for locations, assign awards tier percentages and distribute emissions tokens to location contribution contracts.
contract SCMetagameLocations is SCMetagameGenericDataView {
    using EnumerableMap for EnumerableMap.Bytes32ToUintMap;

    /// @notice Factory for creating locations
    ISCMetagameLocationRewardsFactory public factory;

    /// @notice The emissions token.
    IERC20 public immutable token;

    /// @notice The access pass SBT
    ISCAccessPass public access_pass;
    
    /// @notice The treasury that this contract pulls emissions tokens from.
    /// @dev An allowance must be set on the emissions token contract that permits this contract access to the treasury's tokens.
    address public treasury;

    /// @notice The duration of the emissions epochs.
    uint256 public EPOCH = 7 days;

    /// @notice A mapping of the emissions contribution contracts by location name
    mapping(string => IStakingRewards) public location_rewards;
    
    /// @notice List of the existent location names
    string[] public locations;

    /// @notice The numeric id (start timestamp) of the current epoch
    uint256 public current_epoch = 0;

    /// @notice The numeric id (start timestamp) of the next epoch 
    uint256 public next_epoch = 0;

    mapping(address => EnumerableMap.Bytes32ToUintMap) private user_stakes;
    mapping(bytes32 => string) private location_hashes;

    event LocationAdded(string location);

    error LocationExists(string name);
    error LocationDoesNotExist(string name);
    error LocationNotFinishedStreaming(string name);
    error IncorrectEpoch(uint256 requested_epoch, uint256 current_epoch);
    error NotYetNextEpoch(uint256 next_epoch);
    error CantWithdrawStakingToken();
    error NotEnoughToDistribute();
    error TransferFailure();
    error InputMismatch();
    error InvalidLocationAddress(string location_id, address imposter, address staking_pool);

    /// @param permissions_ Address of the protocol permissions registry. Must conform to IPermissionsManager.
    /// @param token_ Address of the emissions token.
    /// @param metadata_ Address of the protocol metadata registry. Must conform to ISCMetagameRegistry.
    /// @param treasury_ Address of the treasury which holds emissions tokens for use by the Location Cup metagame.
    /// @param access_pass_ Address of the protocol access pass SBT
    constructor(
        address permissions_,
        address factory_,
        address token_,
        address metadata_,
        address treasury_,
        address access_pass_
    ) SCMetagameGenericDataView(permissions_, metadata_) {
        token = IERC20(token_);
        treasury = treasury_;
        access_pass = ISCAccessPass(access_pass_);
        factory = ISCMetagameLocationRewardsFactory(factory_);
    }

    /// @notice Assigns a new factory from which location staking contracts are spawned.
    /// @dev Only callable by address with Systems Admin permissions. 
    /// @param factory_ The new factory's address. 
    function setFactory(address factory_) external isSystemsAdmin {
        factory = ISCMetagameLocationRewardsFactory(factory_);
    }

    /// @notice Assigns a new treasury from which the metagame system draws token rewards.
    /// @dev Only callable by address with Global Admin permissions. Ability to withdraw tokens from treasury_ must be set separately.
    /// @param treasury_ The new treasury's address. 
    function setTreasury(address treasury_) external isGlobalAdmin {
        treasury = treasury_;
    }

    /// @notice Gets the staking contract for a location cast as an ISCMetagameLocationRewards
    /// @param location_name_ The location id.
    /// @return _location_rewards_ The queried location ISCMetagameLocationRewards
    function getLocationRewards(string memory location_name_) view internal returns (ISCMetagameLocationRewards _location_rewards_) {
        _location_rewards_ = ISCMetagameLocationRewards(address(location_rewards[location_name_]));
    }

    /// @notice Gets the staking contract for a location cast as an ISCMetagameDataSource
    /// @param location_name_ The location id.
    /// @return _view_ The queried data source.
    function getLocationView(string memory location_name_) override view internal returns (ISCMetagameDataSource _view_) {
        _view_ = ISCMetagameDataSource(address(location_rewards[location_name_]));
    }

    /// @notice Add a new "Location" to the metagame system.
    /// @dev Only callable by address with System Admin permissions. This creates a new contract which participants can contribute tokens to. This new entity is bound to one of the possible "Locations" that the participants accounts can belong to.
    /// @param location_name_ A name for the new "Location". Must be the same string used by the metadata registry system.
    function addLocation(string calldata location_name_) external isSystemsAdmin {
        if(address(location_rewards[location_name_]) != address(0)) {
            revert LocationExists(location_name_);
        }

        address _location_staker = address(IStakingRewards(
            factory.addLocation(
                location_name_, 
                address(token), 
                address(permissions), 
                address(this), 
                address(access_pass))));

        location_rewards[location_name_] = IStakingRewards(_location_staker);
        locations.push(location_name_);
        location_hashes[keccak256(abi.encodePacked(location_name_))] = location_name_;

        emit LocationAdded(location_name_);
    }

    /// @notice Retreives the address of the contribution repository of the specified "Location".
    /// @param location_name_ The name of the "Location". Must be the same string used by the metadata registry system.
    /// @return address The address of the location's synthetix staking contract
    function getLocationRewardsStaker(string memory location_name_) public view returns (address) {
        return address(location_rewards[location_name_]);
    }

    /// @notice Distribute emissions tokens to each locations contributions contract and initializes the next epoch.
    /// @dev Only callable by address with System Admin permissions. Must be called after the epoch has elapsed. 
    function distributeRewards(uint256 epoch_, string[] memory locations_, uint256[] memory location_reward_shares_) external isSystemsAdmin {
        if(epoch_ != current_epoch) {
            revert IncorrectEpoch(epoch_, current_epoch);
        }
        
        uint256 _next_epoch = next_epoch;
        if(_next_epoch > block.timestamp) {
            revert NotYetNextEpoch(_next_epoch);
        }

        uint256 _length = locations_.length;
        if(_length != location_reward_shares_.length) {
            revert InputMismatch();
        }
        
        uint256 _amount;
        for(uint256 i = 0; i < _length; i++) {
            _amount += location_reward_shares_[i];
        }

        bool _success = token.transferFrom(treasury, address(this), _amount);
        if(!_success) {
            revert NotEnoughToDistribute();
        }
        
        uint256 _duration = EPOCH; //If somehow the epoch was not initialized for an entire epoch span, default to 1 EPOCH in the future
        if((_next_epoch + _duration) > block.timestamp) {
            _duration = (_next_epoch + _duration) - block.timestamp;
        }
        
        uint256 _num_locations = locations_.length;
        for(uint256 i = 0; i < _num_locations; i++) {
            string memory _location = locations_[i];
            IStakingRewards _location_staker = location_rewards[_location];
            
            if(address(_location_staker) == address(0)) {
                revert LocationDoesNotExist(_location);
            }
            if(_location_staker.periodFinish() > block.timestamp) {
                revert LocationNotFinishedStreaming(_location);
            }
            
            uint256 _share = location_reward_shares_[i];
            _location_staker.setRewardsDuration(_duration);
            bool success = token.transfer(address(_location_staker), _share);
            if(!success) {
                revert TransferFailure();
            }
            _location_staker.notifyRewardAmount(_share);
        }

        current_epoch = _next_epoch;
        next_epoch = block.timestamp + _duration;
    }

    /// @notice Transfer tokens that have been sent to this contract by mistake.
    /// @dev Only callable by address with Global Admin permissions. Cannot be called to withdraw emissions tokens.
    /// @param tokenAddress_ The address of the token to recover
    /// @param tokenAmount_ The amount of the token to recover
    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external isGlobalAdmin {
        if(tokenAddress_ == address(token)) {
            revert CantWithdrawStakingToken();
        }
        IERC20(tokenAddress_).transfer(msg.sender, tokenAmount_);
    }

    /// @notice Transfer tokens that have been sent to a location staking contract by mistake.
    /// @dev Only callable by address with Global Admin permissions. Cannot be called to withdraw emissions tokens.
    /// @param location_ The location name of the contract to recover tokens from
    /// @param tokenAddress_ The address of the token to recover
    /// @param tokenAmount_ The amount of the token to recover
    function recoverERC20FromLocation(string calldata location_, address tokenAddress_, uint256 tokenAmount_) external isGlobalAdmin {
        location_rewards[location_].recoverERC20(tokenAddress_, tokenAmount_);
    }

    /// @notice Set a new duration for subsequent epochs
    /// @dev Only callable by address with Systems Admin permissions. 
    /// @param duration_ The new duration in seconds
    function setEpochDuration(uint256 duration_) external isSystemsAdmin {
        EPOCH = duration_;
    }

    /// @notice Read the quantity of locations that exist
    function locationCount() public view returns (uint256 count) {
        count = locations.length;
    }

    /// @notice Read the quantity of locations that exist
    function allLocations() public view returns (string[] memory all_locations) {
        all_locations = locations;
    }

    /// @notice Called by the staking contract to inform on staking activity
    function informStake(address user) public override {
        ISCMetagameLocationRewards _staking_contract = ISCMetagameLocationRewards(msg.sender);
        string memory _location = _staking_contract.location_id();
        IStakingRewards _staking_rewards = location_rewards[_location];
        
        if(address(_staking_rewards) != msg.sender) {
            revert InvalidLocationAddress(_location, msg.sender,address(_staking_rewards));
        }

        bytes32 location_hash = keccak256(abi.encodePacked(_location));
        uint256 _staked_tokens = _staking_contract.user_stakes(user);
        if(_staked_tokens == 0) {
            user_stakes[user].remove(location_hash);
        } else {
            user_stakes[user].set(location_hash, _staked_tokens);
        }
    }

    function getStakedLocations(address user_) public view returns (string[] memory _locations, uint256[] memory _staked_tokens) {
        uint256 _length = user_stakes[user_].length();
        _locations = new string[](_length);
        _staked_tokens = new uint256[](_length);
        for(uint256 i = 0; i < _length; i++) {
            (bytes32 _location_hash, uint256 _quantity) = user_stakes[user_].at(i);
            _locations[i] = location_hashes[_location_hash];
            _staked_tokens[i] = _quantity;
        }
    }

    /// @notice Sets the global multiplier bonus of a specfied address.
    /// @param addr_ The address to set multiplier bonus for.
    /// @param multiplier_bonus_ Value is in basis points. Global bonus multiplier is added to 100% (10_000) to determine multiplier.
    /// @dev Only callable by systems admin
    function setMultiplier(address addr_, uint256 multiplier_bonus_) public override isSystemsAdmin {
        metadata_registry.setMetadata(addr_, BASE_MULTIPLIER, multiplier_bonus_);
    }

    function updateMultipliers(address user_, string[] memory locations_) public {
        if(locations_.length == 0) {
            (locations_,) = getStakedLocations(user_);
        }

        uint256 _length = locations_.length;
        for(uint256 i; i < _length; i++) {
            ISCMetagameLocationRewards _staking_rewards = ISCMetagameLocationRewards(address(location_rewards[locations_[i]]));
            _staking_rewards.updateMultiplier(user_);
        }
    }
}