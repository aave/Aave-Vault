// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract MockAToken is ERC20 {
    constructor() ERC20("Mock aToken", "MAT") {}

    function mint(address _recipient, uint256 _amount) public {
        _mint(_recipient, _amount);
    }

    function burn(address _recipient, uint256 _amount) public {
        _burn(_recipient, _amount);
    }

    function scaledTotalSupply() public view returns (uint256) {
        return totalSupply();
    }
}
