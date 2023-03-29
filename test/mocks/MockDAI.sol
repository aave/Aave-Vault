// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {ERC20Permit} from "@openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract MockDAI is ERC20Permit {
    constructor() ERC20Permit("Mock DAI") ERC20("Mock DAI", "mDAI") {}

    function mint(address to, uint256 value) public {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public {
        _burn(from, value);
    }
}
