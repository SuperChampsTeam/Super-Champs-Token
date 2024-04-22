// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

import "../contracts/ExponentialVestingEscrow.sol";
import "../interfaces/IVestingEscrow.sol";

contract VestingEscrowFactoryStub is IVestingEscrowFactory {
    function deploy_vesting_contract(
        ERC20,
        address,
        uint256,
        uint256,
        uint256, // default to block.timestamp,
        uint256 // default to 0
    ) external returns (IVestingEscrow) {
        return new ExponentialVestingEscrow();
    }
}