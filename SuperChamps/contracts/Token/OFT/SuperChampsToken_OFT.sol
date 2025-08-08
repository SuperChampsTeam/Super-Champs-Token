// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

contract SuperChampsToken_OFT {
    string              CHAMP_TOKEN_NAME    = "Super Champs";
    string              CHAMP_TOKEN_SYMBOL  = "CHAMP";

    uint32 constant     BASE_EID            = 30184;
    uint32 constant     MANTLE_EID          = 30181;

    address constant    BASE_CHAMP_TOKEN    = 0xEb6d78148F001F3aA2f588997c5E102E489Ad341;
    address constant    BASE_SEPOLIA_TOKEN  = 0x20324Ddb80da7F613D1312e9fE1E29F6dc83c6BE;

    address constant    LZ_ENDPOINT_BASE    = 0x1a44076050125825900e736c501f859c50fE728c;
    address constant    LZ_ENDPOINT_MANTLE  = 0x1a44076050125825900e736c501f859c50fE728c;

    address constant    INIT_DELEGATE       = 0x812B41c3769af7AD93BaD03FBE4D4255F080130E;
    address constant    BASE_OWNER          = 0x4642929AB465e5B615687abAa929f68dbD075326;
    address constant    MANTLE_OWNER        = 0x7b6F071e93127d0c135382c81F989fDbeE71f073;
}