// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import { OFTAdapter } from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SuperChampsToken_OFT_Test, ConfigTypeUlnStruct } from "./SuperChampsToken_OFT_Test.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";

contract SuperChampsToken_OFTMantle is OFT, SuperChampsToken_OFT_Test {
    constructor() 
        OFT(        CHAMP_TOKEN_NAME, 
                    CHAMP_TOKEN_SYMBOL, 
                    LZ_ENDPOINT_MANTLE, 
                    MANTLE_OWNER) 
        Ownable(    MANTLE_OWNER) 
    {}

    function initSetup() public onlyOwner {
        setPeer(BASE_EID, bytes32(uint256(uint160(address(this)))));
        
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(LZ_ENDPOINT_BASE);
        address receive_library = endpoint.defaultReceiveLibrary(BASE_EID);
        address send_library = endpoint.defaultSendLibrary(BASE_EID);
        
        address[] memory empty;
        address[] memory dvn = new address[](1);
        dvn[0] = MANTLE_DVN;
        ConfigTypeUlnStruct memory configTypeUlnStruct = ConfigTypeUlnStruct(
            5, 1, 0, 0, dvn, empty
        );

        bytes memory config = abi.encode(configTypeUlnStruct);
        SetConfigParam memory setConfigParam = SetConfigParam(BASE_EID, 2, config);
        SetConfigParam[] memory configs = new SetConfigParam[](1);
        configs[0] = setConfigParam;

        endpoint.setConfig(address(this), receive_library, configs);
        endpoint.setConfig(address(this), send_library, configs);
    }
}