// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVestingFactory {
    function deploy_vesting_contract (
        IERC20 token,
        address recipient,
        uint256 amount,
        uint256 vesting_duration,
        uint256 vesting_start,
        uint256 cliff_length,
        bool open_claim,
        uint256 support_vyper,
        address owner) external returns (address);
}


/// @title SECURE TOKEN VESTING STREAM SPLITTER
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice This is an ERC20 token splitter ehat allows a token recipient flexibility in how to split their tokens to multiple owned wallets, without allowing them to bypass vesting requirements.
contract VestingSplitter {
    IVestingFactory factory;
    address splitter;
    address creator;

    uint256 vesting_duration; 
    uint256 vesting_start; 
    uint256 cliff_length;

    event StreamCreated(address recipient, uint256 amount, address stream);

    constructor(address _admin, address _factory, uint256 _vesting_duration, uint256 _vesting_start, uint256 _cliff_length) {
        creator = msg.sender;
        splitter = _admin;
        factory = IVestingFactory(_factory);
        vesting_duration = _vesting_duration;
        vesting_start = _vesting_start;
        cliff_length = _cliff_length;
    }
    
    function SplitTokens(IERC20 token, address[] memory recipients, uint256[] memory amounts) external {
        require(msg.sender == splitter, "NO AUTH");
        require(amounts.length == recipients.length, "INVALID INPUTS");

        uint256 disbursed = 0;
        uint256 balance = token.balanceOf(address(this));
        token.approve(address(factory), balance);

        for(uint256 i = 0; i < recipients.length; i++) {
            address r = recipients[i];
            uint256 a = amounts[i];
            disbursed += a;

            require(disbursed <= balance, "AMOUNTS TOO MUCH");
            address c = factory.deploy_vesting_contract(
                token,
                r,
                a,
                vesting_duration,
                vesting_start,
                cliff_length,
                false,
                0,
                address(0));
            
            emit StreamCreated(r,a,c);
        }

        require(disbursed == balance, "INVALID AMOUNTS");
    }

    function RescueTokens(IERC20 token) external {
        require(msg.sender == creator, "NO AUTH");
        uint256 balance = token.balanceOf(address(this));
        token.transfer(creator, balance);
    }
}