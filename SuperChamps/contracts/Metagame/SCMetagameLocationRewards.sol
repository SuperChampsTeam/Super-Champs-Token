// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import { StakingRewards } from "../../../Synthetix/contracts/StakingRewards.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/ISCMetagameDataSource.sol";
import "../../interfaces/ISCAccessPass.sol";

/// @title Location membership gated extension of a Synthetix StakingRewards contract
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice Requires that a contributor belong to the associated location, as defined by the protocol metadata registry.
contract SCMetagameLocationRewards is StakingRewards {
    /// @notice The metadata registry
    ISCMetagameDataSource immutable metagame_data;

    /// @notice The name of the associated location
    string public location_id;

    /// @notice The access pass SBT
    ISCAccessPass public access_pass;

    /// @dev The recorded multipliers (if any) of users who have deposited tokens.
    mapping(address => uint256) internal _multiplier_basis_points;
    
    /// @param token_ Address of the emissions token.
    /// @param metagame_data_ Address of the metagame data view. Must conform to ISCMetagameDataSource.
    /// @param location_id_ String representation of the name of the associated "Location"
    /// @param access_pass_ Address of the protocol access pass SBT
    constructor(
        address token_,
        address metagame_data_,
        string memory location_id_,
        address access_pass_
    ) StakingRewards(address(msg.sender), address(msg.sender), token_, token_) {
        metagame_data = ISCMetagameDataSource(metagame_data_);
        location_id = location_id_;
        access_pass = ISCAccessPass(access_pass_);
    }

    /// @notice Identical to base contract except that only specific users may deposit tokens. See {StakingRewards-stake}.
    function stake(uint256 amount_) external override nonReentrant notPaused updateReward(msg.sender) {
        require(metagame_data.getMembership(msg.sender, location_id), "MUST BE IN HOUSE");
        require(access_pass.isVerified(msg.sender), "MUST HAVE VERIFIED ACCESS PASS");
        require(amount_ > 0, "CANNOT STAKE 0");

        uint256 _old_multiplier_basis_points = _multiplier_basis_points[msg.sender];
        _multiplier_basis_points[msg.sender] = metagame_data.getMultiplier(msg.sender, location_id);

        _totalSupply -= _balances[msg.sender] * _old_multiplier_basis_points / 10000;
        _totalSupply = _totalSupply + ((_balances[msg.sender]+amount_) * _multiplier_basis_points[msg.sender] / 10000);
        _balances[msg.sender] = _balances[msg.sender] + amount_;
        stakingToken.transferFrom(msg.sender, address(this), amount_);

        emit Staked(msg.sender, amount_);
    }

    function updateMultiplier(address addr_) internal returns (uint256 _mult_bp)
    {
	    _mult_bp = metagame_data.getMultiplier(addr_, location_id);

	    if(_mult_bp != _multiplier_basis_points[addr_])
        {
            uint256 _old_multiplier = _multiplier_basis_points[addr_];
            _multiplier_basis_points[addr_] = _mult_bp;
            _totalSupply = _totalSupply - ((_balances[addr_] * _old_multiplier) / 10000);
            _totalSupply = _totalSupply + ((_balances[addr_] * _mult_bp) / 10000);
        }
    }

    function withdraw(uint256 amount) public override nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");

	    uint256 _mult_bp = updateMultiplier(msg.sender);
	
        _totalSupply = _totalSupply - ((amount * _mult_bp) / 10000);
        _balances[msg.sender] = _balances[msg.sender] - amount;
        stakingToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function earned(address account) public override view returns (uint256 _earned) {
        _earned = (
	    	(( _multiplier_basis_points[account] * _balances[account]) / 10000) * 
	    	(rewardPerToken() - userRewardPerTokenPaid[account])
	    ) / 1e18 + 
	    rewards[account];
    }

    modifier updateReward(address account) override {
	    updateMultiplier(msg.sender);
        
	    rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }
}