// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

struct ConfigTypeUlnStruct {
    uint64 confirmations;
    uint8 requiredDVNCount;
    uint8 optionalDVNCount;
    uint8 optionalDVNThreshold;
    address[] requiredDVNs; 
    address[] optionalDVNs;
}

contract SuperChampsToken_OFT_Test {
    string              CHAMP_TOKEN_NAME    = "Super Champs";
    string              CHAMP_TOKEN_SYMBOL  = "CHAMP";

    uint32 constant     BASE_EID            = 40245;
    uint32 constant     MANTLE_EID          = 40246;

    address constant    BASE_CHAMP_TOKEN    = 0x20324Ddb80da7F613D1312e9fE1E29F6dc83c6BE;

    address constant    LZ_ENDPOINT_BASE    = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address constant    LZ_ENDPOINT_MANTLE  = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    address constant    INIT_DELEGATE       = 0x812B41c3769af7AD93BaD03FBE4D4255F080130E;
    address constant    BASE_OWNER          = 0x812B41c3769af7AD93BaD03FBE4D4255F080130E;
    address constant    MANTLE_OWNER        = 0x812B41c3769af7AD93BaD03FBE4D4255F080130E;

    address constant    BASE_DVN            = 0xe1a12515F9AB2764b887bF60B923Ca494EBbB2d6;
    address constant    MANTLE_DVN          = 0x9454f0EABc7C4Ea9ebF89190B8bF9051A0468E03;
}