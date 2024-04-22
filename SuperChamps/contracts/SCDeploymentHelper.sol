// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PermissionsManager.sol";
import "./ExponentialVestingEscrow.sol";
import "./TransferLockERC20.sol";

contract SCDeploymentHelper {
    IPermissionsManager immutable private _permissions;
    TransferLockERC20 private _token;

    address private constant SUPER_CHAMPS_MINTER = address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);

    address private constant JOYRIDE = address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4); //need correct address
    uint256 private constant JOYRIDE_ALLOCATION = 400_000_000 ether;

    address private constant SUPER_CHAMPS_FOUNDATION = address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2); //need correct address
    uint256 private constant SUPER_CHAMPS_FOUNDATION_ALLOCATION = 600_000_000 ether;

    uint256 private constant EMISSIONS_RATE_NUMERATOR = 7_687_484;
    uint256 private constant EMISSIONS_RATE_DIVISOR = 1_000_000_000_000_000;
    //7_687_484 / 1_000_000_000_000_000 = 0.000000007687484059
    //1 - 0.000000007687484059 = 0.999999992312516
    //2_592_000 = 30 days in seconds
    //1 - (0.999999992312516^2_592_000) = 0.01972874872884055070910246094836 <= emissions per 30 days, target is ~2%

    modifier isMintAdmin() {
        require(_permissions.hasRole(IPermissionsManager.Role.MINT_ADMIN, msg.sender));
        _;
    }

    modifier isGlobalAdmin() {
        require(_permissions.hasRole(IPermissionsManager.Role.GLOBAL_ADMIN, msg.sender));
        _;
    }

    constructor() {
        _permissions = new PermissionsManager();
        _permissions.addRole(IPermissionsManager.Role.GLOBAL_ADMIN, msg.sender);
        _permissions.addRole(IPermissionsManager.Role.GLOBAL_ADMIN, JOYRIDE);
        _permissions.addRole(IPermissionsManager.Role.GLOBAL_ADMIN, SUPER_CHAMPS_FOUNDATION);

        _permissions.addRole(IPermissionsManager.Role.MINT_ADMIN, SUPER_CHAMPS_MINTER);
    }

    function tokenGenerationEvent() 
        public isMintAdmin
    {
        require(_token == TransferLockERC20(address(0)));
        uint256 _total_supply = JOYRIDE_ALLOCATION + SUPER_CHAMPS_FOUNDATION_ALLOCATION;

        _token = new TransferLockERC20("Super Champs", "CHAMP", _total_supply, _permissions);
        _permissions.addRole(IPermissionsManager.Role.TRANSFER_ADMIN, address(_token));
        _token.tokenGenerationEvent();

        _token.transfer(JOYRIDE, JOYRIDE_ALLOCATION);
        _token.transfer(SUPER_CHAMPS_FOUNDATION, SUPER_CHAMPS_FOUNDATION_ALLOCATION);
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

        _token.transferFrom(msg.sender, address(this), allocation_);
        _token.approve(address(_emissions), allocation_);

        _emissions.initialize(
            address(0),
            address(_token),
            treasury_,
            allocation_,
            start_time_,
            EMISSIONS_RATE_NUMERATOR,
            EMISSIONS_RATE_DIVISOR
        );
    }
}