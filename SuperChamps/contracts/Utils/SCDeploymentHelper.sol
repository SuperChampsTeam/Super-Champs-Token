// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PermissionsManager.sol";
import "../Token/ExponentialVestingEscrow.sol";
import "../Token/SuperChampsToken.sol";

contract SCDeploymentHelper {
    IPermissionsManager immutable private _permissions;
    SuperChampsToken public token;

    uint256 private constant TOTAL_SUPPLY = 1_000_000_000 ether;

    address private constant SUPER_CHAMPS_MINTER = address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);

    address private constant JOYRIDE = address(0xa8CAc43b28A7e5F0Ee797741195A920E88B8e7EB); //Joyride BASE Gnosis Safe
    uint256 private constant JOYRIDE_ALLOCATION = 320_000_000 ether;

    address private constant SUPER_CHAMPS_FOUNDATION = address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2); //need correct address
    uint256 private constant SUPER_CHAMPS_FOUNDATION_ALLOCATION = 680_000_000 ether;

    uint256 private constant EMISSIONS_RATE_NUMERATOR = 778;
    uint256 private constant EMISSIONS_RATE_DIVISOR = 100_000_000_000;
    //778 / 100_000_000_000 = 0.00000000778
    //1 - 0.00000000778 = 0.99999999222
    //2_592_000 = 30 days in seconds
    //1 - (0.99999999222^2_592_000) = 0.01996379103680036030655598958972 pool contents emissions per 30 days, target is ~2%

    modifier isGlobalAdmin() {
        require(_permissions.hasRole(IPermissionsManager.Role.GLOBAL_ADMIN, msg.sender));
        _;
    }

    constructor() {
        _permissions = new PermissionsManager();
        
        address[] memory _mint_recipients = new address[](2);
        uint256[] memory _mint_quantities = new uint256[](2);
        _mint_recipients[0] = JOYRIDE;
        _mint_recipients[1] = SUPER_CHAMPS_FOUNDATION;
        _mint_quantities[0] = JOYRIDE_ALLOCATION;
        _mint_quantities[1] = SUPER_CHAMPS_FOUNDATION_ALLOCATION;

        token = new SuperChampsToken("Super Champs", "CHAMP", TOTAL_SUPPLY, _permissions);

        _permissions.addRole(IPermissionsManager.Role.TRANSFER_ADMIN, JOYRIDE);
        _permissions.addRole(IPermissionsManager.Role.TRANSFER_ADMIN, address(token));
        _permissions.addRole(IPermissionsManager.Role.GLOBAL_ADMIN, SUPER_CHAMPS_FOUNDATION);

        token.tokenGenerationEvent(_mint_recipients, _mint_quantities);

        require(token.totalSupply() == TOTAL_SUPPLY, "SUPPLY MISMATCH");
        require(token.balanceOf(JOYRIDE) == JOYRIDE_ALLOCATION, "JOYRIDE MISMATCH");
        require(token.balanceOf(SUPER_CHAMPS_FOUNDATION) == SUPER_CHAMPS_FOUNDATION_ALLOCATION, "FOUNDATION MISMATCH");
    }
    
    function initializeEmmissions(
        address treasury_,
        uint256 allocation_,
        uint256 start_time_
    )
        public isGlobalAdmin
    {
        ExponentialVestingEscrow _emissions = new ExponentialVestingEscrow(address(_permissions));
        _permissions.addRole(IPermissionsManager.Role.TRANSFER_ADMIN, address(_emissions));

        token.transferFrom(msg.sender, address(this), allocation_);
        token.approve(address(_emissions), allocation_);

        _emissions.initialize(
            address(0),
            address(token),
            treasury_,
            allocation_,
            start_time_,
            EMISSIONS_RATE_NUMERATOR,
            EMISSIONS_RATE_DIVISOR
        );
    }
}