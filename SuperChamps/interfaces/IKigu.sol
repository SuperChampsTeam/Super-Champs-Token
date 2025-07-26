// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Burnable.sol";

interface IKigu is IERC20, IERC20Burnable {

    function mint(address to, uint amount) external returns (bool);

}
