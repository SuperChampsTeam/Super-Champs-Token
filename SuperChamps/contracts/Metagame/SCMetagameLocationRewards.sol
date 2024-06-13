// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import { StakingRewards } from "../../../Synthetix/contracts/StakingRewards.sol";
import "../Utils/SCPermissionedAccess.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/ISCMetagameDataSource.sol";
import "../../interfaces/ISCMetagameLocationRewards.sol";
import "../../interfaces/ISCMetagameRegistry.sol";
import "../../interfaces/ISCAccessPass.sol";

/// @title Location membership gated extension of a Synthetix StakingRewards contract
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice Requires that a contributor belong to the associated location, as defined by the protocol metadata registry.
contract SCMetagameLocationRewards is ISCMetagameDataSource, ISCMetagameLocationRewards, StakingRewards, SCPermissionedAccess {
    /// @notice The location manager metadata view
    ISCMetagameDataSource public immutable metagame_data;

    /// @notice The name of the associated location
    string public location_id;

    /// @notice The metadata key of the associated location's multiplier bonus
    string public location_multiplier_key;

    /// @notice The access pass SBT
    ISCAccessPass public access_pass;

    /// @notice The true staked supply
    uint256 public staked_supply;

    /// @notice The true staked supply
    mapping(address => uint256) public user_stakes;

    /// @dev The recorded multipliers (if any) of users who have deposited tokens.
    mapping(address => uint256) internal _multiplier_basis_points;
    
    /// @param token_ Address of the emissions token.
    /// @param metagame_data_ Address of the metagame data view. Must conform to ISCMetagameDataSource.
    /// @param location_id_ String representation of the name of the associated "Location"
    /// @param access_pass_ Address of the protocol access pass SBT
    constructor(
        address token_,
        address permissions_,
        address metagame_data_,
        string memory location_id_,
        address access_pass_

    ) StakingRewards(address(msg.sender), address(msg.sender), token_, token_) SCPermissionedAccess(permissions_) {
        metagame_data = ISCMetagameDataSource(metagame_data_);
        location_id = location_id_;
        location_multiplier_key = string(abi.encode(location_id_, "_multiplier"));
        access_pass = ISCAccessPass(access_pass_);
        rewardsDuration = 0;
    }

    /// @param addr_ Address of the staker who needs to have their multiplier updated
    /// @notice Updates an accounts bonus multiplier from the metagame metadata system.
    /// @dev Underlying balance is assumed to be stored as a pre-multiplied quantity.
    function updateMultiplier(address addr_) public updateReward(addr_) returns (uint256 _mult_bp)
    {
	    _mult_bp = getTotalMultiplier(addr_);

	    if(_mult_bp != _multiplier_basis_points[addr_])
        {
            uint256 _old_multiplier = _multiplier_basis_points[addr_];
            _multiplier_basis_points[addr_] = _mult_bp;

            _totalSupply -= _balances[addr_];
            _balances[addr_] = (_balances[addr_] * _mult_bp) / _old_multiplier;
            _totalSupply += _balances[addr_];
        }
    }

    /// @notice Identical to base contract except that it uses a multiplier for bonus rewards and only specific users may deposit tokens. 
    /// @notice See {StakingRewards-stake}.
    function stake(uint256 amount_) external override nonReentrant notPaused updateReward(msg.sender) {
        require(getMembership(msg.sender, location_id), "MUST BE MEMBER OF LOCATION");
        require(access_pass.isVerified(msg.sender), "MUST HAVE VERIFIED ACCESS PASS");
        require(amount_ > 0, "CANNOT STAKE 0");

        staked_supply += amount_;
        user_stakes[msg.sender] += amount_;

        uint256 multiplied_amount_ = amount_ * _multiplier_basis_points[msg.sender];
        _totalSupply += multiplied_amount_;
        _balances[msg.sender] += multiplied_amount_;

        stakingToken.transferFrom(msg.sender, address(this), amount_);
        emit Staked(msg.sender, amount_);
    }

    /// @notice Identical to base contract except that it uses a multiplier for bonus rewards and only specific users may deposit tokens. 
    /// @notice See {StakingRewards-stake}.
    function withdraw(uint256 amount) public override nonReentrant {
        _withdraw(msg.sender, amount);
    }

    function _withdraw(address from, uint256 amount) internal virtual updateReward(from) {
        require(amount > 0, "Cannot withdraw 0");

	    uint256 _mult_bp = _multiplier_basis_points[from];
        uint256 _multiplied_amount = (amount * _mult_bp);
	
        _totalSupply -= _multiplied_amount;
        _balances[from] -= _multiplied_amount;

        staked_supply -= amount;
        user_stakes[from] -= amount;
        stakingToken.transfer(from, amount);
        emit Withdrawn(from, amount);
    }

    function exit() override external {
        withdraw(user_stakes[msg.sender]);
        getReward();
    }

    function spend(address from, address to, uint256 value) external isSystemsAdmin {
        _withdraw(from, value);
        stakingToken.transferFrom(from, to, value);
    }

    function notifyRewardAmount(uint256 reward) external override onlyRewardsDistribution updateReward(address(0)) {
        if (timestamp() >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - timestamp();
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        // If staking and rewards token are the same, ensure the balance reflects on the non-staked tokens.
        uint balance = rewardsToken.balanceOf(address(this));
        if(stakingToken == rewardsToken) {
            balance -= staked_supply;
        }

        require(rewardRate <= balance / rewardsDuration, "Provided reward too high");

        lastUpdateTime = timestamp();
        periodFinish = timestamp() + rewardsDuration;
        emit RewardAdded(reward);
    }

    /// @notice Queries if a specfied address is a member of a specified location.
    /// @param addr_ The address to query.
    /// @param location_ The location id to query.
    /// @return _result bool Returns true if the address is a member of the location.
    function getMembership(address addr_, string memory location_) public view returns (bool) {
        return metagame_data.getMembership(addr_, location_);
    }

    /// @notice Returns the metadata registry by way of the parent metadata view
    function metadata_registry() public view returns (ISCMetagameRegistry) {
        return metagame_data.metadata_registry();
    }
    
    /// @notice Sets the local multiplier bonus of a specfied address.
    /// @param addr_ The address to set multiplier bonus for.
    /// @param multiplier_bonus_ Value is in basis points. Global bonus multiplier is added to 100% (10_000) to determine multiplier.
    /// @dev Only callable by systems admin
    function setMultiplier(address addr_, uint256 multiplier_bonus_) public virtual isSystemsAdmin {
        metadata_registry().setMetadata(addr_, location_multiplier_key, multiplier_bonus_);
    }

    /// @notice Queries the global multiplier bonus of a specfied address.
    /// @param addr_ The address to query.
    /// @return _result uint256 Returns the numeric metadata mapped to that address, in basis points. 
    /// @dev Global bonus multiplier is added to 100% (10_000) to determine multiplier.
    function getMultiplier(address addr_) public view virtual returns (uint256) {
        return metadata_registry().metadataUInt(addr_, location_multiplier_key);
    }

    /// @notice Queries the bonus multiplier of a specfied address at a specified location.
    /// @param addr_ The address to query.
    /// @return _result uint256 Returns the numeric metadata mapped to that address, in basis points
    function getTotalMultiplier(address addr_) public view returns (uint256) {
        return metagame_data.getTotalMultiplier(addr_) + getMultiplier(addr_);
    }
}