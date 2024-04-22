// SPDX-License-Identifier: None
// Joyride Games 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../interfaces/IPermissionsManager.sol";

//Semi-Fungible Soul Bound Token (SBT)
contract SCAccessPass is ERC1155 {
    IPermissionsManager private immutable _permissions;
    mapping(address => bool) public _verified;
    uint256 public price = 0.001 ether;

    modifier isSystemsAdmin() {
        require(_permissions.hasRole(IPermissionsManager.Role.SYSTEMS_ADMIN, msg.sender));
        _;
    }

    constructor(
        IPermissionsManager permissions_,
        string memory uri_
    ) ERC1155(uri_) { 
        _permissions = permissions_;
    }

    function setURI(string memory uri_) external isSystemsAdmin {
        _setURI(uri_);
    }

    function setPrice(uint256 price_) external isSystemsAdmin {
        price = price_;
    }

    function collect(address payable recipient_) external isSystemsAdmin {
        recipient_.transfer(address(this).balance);
    }

    function verifyPassHolder(address holder_, bool status_) external isSystemsAdmin {
        require(isPassHolder(holder_), "NOT REGISTERED");
        require(_verified[holder_] != status_, "ALREADY SET/UNSET");
        _verified[holder_] = status_;
    }

    function register() external payable {
        require(balanceOf(_msgSender(), 0) == 0, "ALREADY MINTED SBT");
        require(msg.value == price, "INVALID PAYMENT");
        _mint(_msgSender(), 0, 1, "");
    }

    function isPassHolder(address addr_) external view returns (bool _result) {
        _result = (balanceOf(addr_, 0) > 0);
    }

    function isVerified(address addr_) external view returns (bool _result) {
        _result = _verified[addr_];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(address, address, uint256, uint256, bytes memory) public pure override {
        revert("SBT");
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure override {
        revert("SBT");
    }
}