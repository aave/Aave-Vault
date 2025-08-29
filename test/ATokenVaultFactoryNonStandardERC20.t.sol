// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {MockUSDT} from "./mocks/MockUSDT.sol";

contract ATokenVaultFactoryNonStandardERC20Test {
    
    function _deployUnderlying() internal virtual returns (address) {
        return address(new MockUSDT());
    }
}
