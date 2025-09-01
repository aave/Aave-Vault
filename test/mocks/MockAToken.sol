// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract MockAToken is ERC20 {
    using SafeERC20 for ERC20;

    address internal _underlyingAsset;

    constructor(address underlyingAsset) ERC20("Mock aToken", "MAT") {
        _underlyingAsset = underlyingAsset;
    }

    function mint(address /* caller */, address onBehalfOf, uint256 amount, uint256 /* index */) external returns (bool) {
        _mint(onBehalfOf, amount);
        return true;
    }

    function burn(address from, address receiverOfUnderlying, uint256 amount, uint256 /* index */) external {
        _burn(from, amount);
        if (receiverOfUnderlying != address(this)) {
            ERC20(_underlyingAsset).safeTransfer(receiverOfUnderlying, amount);
        }
    }

    function scaledTotalSupply() public view returns (uint256) {
        return totalSupply();
    }
}
