// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3} from "../../../solmate/src/utils/CREATE3.sol";

/// @title Factory for deploying contracts to deterministic addresses via CREATE3
/// @author modified from code by zefram.eth
/// @notice Enables deploying contracts using CREATE3. Each deployer (msg.sender) has
/// its own namespace for deployed addresses.
interface ICREATE3Factory {
    /// @notice Deploys a contract using CREATE3
    /// @dev The provided salt is hashed together with msg.sender to generate the final salt
    /// @param salt The deployer-specific salt for determining the deployed contract's address
    /// @param creationCode The creation code of the contract to deploy
    /// @return deployed The address of the deployed contract
    function deploy(uint256 salt, bytes memory creationCode)
        external
        payable
        returns (address deployed);

    /// @notice Predicts the address of a deployed contract
    /// @dev The provided salt is hashed together with the deployer address to generate the final salt
    /// @param salt The deployer-specific salt for determining the deployed contract's address
    /// @return deployed The address of the contract that will be deployed
    function getDeployed(uint256 salt)
        external
        view
        returns (address deployed);
}

/// @title Factory for deploying contracts to deterministic addresses via CREATE3
/// @author zefram.eth
/// @notice Enables deploying contracts using CREATE3. Each deployer (msg.sender) has
/// its own namespace for deployed addresses.
contract CREATE3Factory is ICREATE3Factory {
    /// @inheritdoc	ICREATE3Factory
    function deploy(uint256 salt, bytes memory creationCode)
        external
        payable
        override
        returns (address deployed)
    {
        require(msg.sender == 0x7b6F071e93127d0c135382c81F989fDbeE71f073 || 
                msg.sender == 0x4642929AB465e5B615687abAa929f68dbD075326, 
                "NOT AUTHORIZED DEPLOYER");
        
        return CREATE3.deploy(bytes32(salt), creationCode, msg.value);
    }

    /// @inheritdoc	ICREATE3Factory
    function getDeployed(uint256 salt)
        external
        view
        override
        returns (address deployed)
    {
        return CREATE3.getDeployed(bytes32(salt));
    }
}