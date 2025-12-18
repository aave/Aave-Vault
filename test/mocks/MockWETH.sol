// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract MockWETH is ERC20 {
    constructor() ERC20("Mock WETH", "mWETH") {}
}
