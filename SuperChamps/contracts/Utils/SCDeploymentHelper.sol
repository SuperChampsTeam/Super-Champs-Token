// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PermissionsManager.sol";
import "../Token/ExponentialVestingEscrow.sol";
import "../Token/SuperChampsToken.sol";

/// @title A deployment helper contract which simplifies the entire initial protocol setup.
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice Protocol setup and Token generation are simplified to the deployment of a single contract. 
/// @dev Additionally contains a function that simplifies the creation of emissions pools.
contract SCDeploymentHelper {
    ///@notice The protocol permissions registry which is created when this is deployed.
    IPermissionsManager immutable public permissions;

    ///@notice The protocol token (CHAMP) which is created when this is deployed.
    SuperChampsToken public token;

    ///@notice The total supply of the CHAMP token
    uint256 private constant TOTAL_SUPPLY = 1_000_000_000 ether;

    ///@notice The address of the Base multisig wallet that is controlled by Joyride
    address private constant JOYRIDE = address(0xa8CAc43b28A7e5F0Ee797741195A920E88B8e7EB);
    ///@notice The quantity of tokens to mint into the Base multisig wallet that is controlled by Joyride as a retained right.
    uint256 private constant JOYRIDE_ALLOCATION = 320_000_000 ether;

    ///@notice The address of the Base multisig wallet that is controlled by The Super Champs Foundation
    address private constant SUPER_CHAMPS_FOUNDATION = address(0x423bA9539440ec39B573Ed5F0eD98e1Ed39cD634);//address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2); //need correct address
    ///@notice The quantity of tokens to mint into the Base multisig wallet that is controlled by The Super Champs Foundation.
    uint256 private constant SUPER_CHAMPS_FOUNDATION_ALLOCATION = 680_000_000 ether;

    ///@notice The numerator of the per second emissions rate of the emissions pool contracts.
    ///@dev 778 / 100_000_000_000 = 0.00000000778 | 1 - 0.00000000778 = 0.99999999222 | 2_592_000 = 30 days in seconds | 1 - (0.99999999222^2_592_000) = 0.01996379103680036030655598958972 pool contents emissions per 30 days, target is ~2%
    uint256 private constant EMISSIONS_RATE_NUMERATOR = 778;

    ///@notice The devisor of the per second emissions rate of the emissions pool contracts.
    uint256 private constant EMISSIONS_RATE_DIVISOR = 100_000_000_000;
    
    ///@notice A function modifier that restricts execution to Global Admins.
    modifier isGlobalAdmin() {
        require(permissions.hasRole(IPermissionsManager.Role.GLOBAL_ADMIN, msg.sender));
        _;
    }

    constructor() {

        permissions = new PermissionsManager();
        
        address[] memory _mint_recipients = new address[](2);
        uint256[] memory _mint_quantities = new uint256[](2);
        _mint_recipients[0] = JOYRIDE;
        _mint_recipients[1] = SUPER_CHAMPS_FOUNDATION;
        _mint_quantities[0] = JOYRIDE_ALLOCATION;
        _mint_quantities[1] = SUPER_CHAMPS_FOUNDATION_ALLOCATION;

        token = new SuperChampsToken("Super Champs", "CHAMP", TOTAL_SUPPLY, permissions);

        permissions.addRole(IPermissionsManager.Role.TRANSFER_ADMIN, JOYRIDE);
        permissions.addRole(IPermissionsManager.Role.TRANSFER_ADMIN, address(token));
        permissions.addRole(IPermissionsManager.Role.GLOBAL_ADMIN, SUPER_CHAMPS_FOUNDATION);

        token.tokenGenerationEvent(_mint_recipients, _mint_quantities);

        require(token.totalSupply() == TOTAL_SUPPLY, "SUPPLY MISMATCH");
        require(token.balanceOf(JOYRIDE) == JOYRIDE_ALLOCATION, "JOYRIDE MISMATCH");
        require(token.balanceOf(SUPER_CHAMPS_FOUNDATION) == SUPER_CHAMPS_FOUNDATION_ALLOCATION, "FOUNDATION MISMATCH");
    }

     function getERC20Address() external view returns (address _result) {
        _result = address(token);
    }

    function getPermissionManagerAddress() external view returns (address _result) {
        _result = address(permissions);
    }
    
    ///@notice A helper which initializes an emissions pool that has the specified treasury set as its beneficiary.
    ///@dev Utilizes the stored EMISSIONS_RATE_NUMERATOR and EMISSIONS_RATE_DIVISOR
    ///@param treasury_ The beneficiary of the emissions contract.
    ///@param allocation_ The quantity of tokens to transfer from msg.sender into the emissions pool.
    ///@param start_time_ The timestamp at which the emissions are to start. May be back dated to create a pool that has some emissions already available.
    function initializeEmmissions(
        address treasury_,
        uint256 allocation_,
        uint256 start_time_
    )
        public isGlobalAdmin returns (address)
    {
        ExponentialVestingEscrow _emissions = new ExponentialVestingEscrow(address(permissions));
        permissions.addRole(IPermissionsManager.Role.TRANSFER_ADMIN, address(_emissions));

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
        return address(_emissions);
    }

    /// @notice Transfer tokens that have been sent to this contract by mistake.
    /// @dev Only callable by address with Global Admin permissions. Cannot be called to withdraw emissions tokens.
    /// @param tokenAddress_ The address of the token to recover
    /// @param tokenAmount_ The amount of the token to recover
    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external isGlobalAdmin {
        IERC20(tokenAddress_).transfer(msg.sender, tokenAmount_);
    }
}