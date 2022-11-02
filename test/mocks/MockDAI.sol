// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract MockDAI is ERC20 {
    constructor() ERC20("Mock DAI", "mDAI", 18) {}

    function mint(address to, uint256 value) public {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public {
        _burn(from, value);
    }
}
