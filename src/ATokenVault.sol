// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";

import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract ATokenVault is ERC4626 {
    constructor(ERC20 aToken) ERC4626(aToken, "Wrapped [aTKN]", "w[aTKN]") {}

    function totalAssets() public view override returns (uint256) {
        return 0;
    }
}
