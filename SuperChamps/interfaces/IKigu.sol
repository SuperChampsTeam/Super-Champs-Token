// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

interface IKigu {


   function balanceOf(address owner) external view returns (uint);

    function mint(address to, uint amount) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);

    function approve(address spender, uint value) external returns (bool);
}
