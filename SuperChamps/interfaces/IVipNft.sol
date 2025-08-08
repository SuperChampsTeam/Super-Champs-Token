// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

interface IVipNft {
    function mint(uint256 _tokenId, address _to, string memory _tokenMetadataURI) external;
}