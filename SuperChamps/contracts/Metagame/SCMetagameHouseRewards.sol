// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

import { StakingRewards } from "../../../synthetix/contracts/StakingRewards.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/ISCMetagameRegistry.sol";


contract SCMetagameHouseRewards is StakingRewards {
    string constant HOUSE_ID_KEY = "house_id";

    ISCMetagameRegistry immutable metadata;
    string public house_id;
    bytes32 house_hash;

    constructor(
        address token_,
        address metadata_,
        string memory house_id_
    ) StakingRewards(address(msg.sender), address(msg.sender), token_, token_) {
        metadata = ISCMetagameRegistry(metadata_);
        house_id = house_id_;
        house_hash = keccak256(bytes(house_id));
    }

    /**
     * @dev See {StakingRewards-stake}.
     */
    function stake(uint256 amount_) external override nonReentrant notPaused updateReward(msg.sender) {
        bytes32 _sender_house_hash = keccak256(abi.encodePacked(metadata.metadataFromAddress(msg.sender, HOUSE_ID_KEY)));
        require(_sender_house_hash == house_hash);
        require(amount_ > 0, "Cannot stake 0");

        _totalSupply = _totalSupply + amount_;
        _balances[msg.sender] = _balances[msg.sender] + amount_;
        stakingToken.transferFrom(msg.sender, address(this), amount_);

        emit Staked(msg.sender, amount_);
    }
}