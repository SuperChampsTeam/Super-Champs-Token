// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "../../../Gnosis/interfaces/IGnosisSafeProxyFactory.sol";

/// @title A deployment helper contract which simplifies the safe setup for token vesting
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice Allows a large quantity of gnosis safes to be created in a single function call.
contract DeployGnosisProxies {
    IGnosisSafeProxyFactory FACTORY = IGnosisSafeProxyFactory(address(0xC22834581EbC8527d974F8a1c97E1bEA4EF910BC));

    event SafesCreated(address[] signers, address[] safes);

    function createSafes(address[] memory signers_) public returns (address[] memory _safes_) {
        _safes_ = new address[](signers_.length);
        bytes memory empty = bytes("");

        for(uint256 i = 0; i < signers_.length; i++) {
            address[] memory _addr = new address[](1);
            _addr[0] = signers_[i];

            bytes memory _init_data = abi.encodeWithSelector(bytes4(keccak256(
                "setup(address[],uint256,address,bytes,address,address,uint256,address)")), 
                _addr,1,address(0),empty,address(0x017062a1dE2FE6b99BE3d9d37841FeD19F573804),address(0),0,address(0));
            
            _safes_[i] = FACTORY.createProxyWithNonce(
                address(0xfb1bffC9d739B8D520DaF37dF666da4C687191EA),
                _init_data,
                12345
            );
        }

        emit SafesCreated(signers_, _safes_);
    }
}