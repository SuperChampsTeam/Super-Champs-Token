// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;


interface IKigu {

    function mint(address to, uint amount) external returns (bool);
    function burn(uint256 value) external;
    function burnFrom(address from, uint256 value) external;

}
