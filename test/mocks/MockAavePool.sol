// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockAToken} from "./MockAToken.sol";

contract MockAavePool {
    struct ReserveData {
        address aTokenAddress;
    }

    uint256 constant SCALE = 1e18;

    MockAToken public aToken;

    constructor(MockAToken _aToken) {
        aToken = _aToken;
    }

    function getReserveData(address _reserve) public returns (ReserveData memory) {
        return ReserveData(address(aToken));
    }

    function supply(
        address _asset,
        uint256 _amount,
        address _onBehalfOf,
        uint256 _referralCode
    ) public {
        ERC20(_asset).transferFrom(msg.sender, address(this), _amount);
        aToken.mint(_onBehalfOf, _amount);
    }

    function withdraw(
        address _asset,
        uint256 _amount,
        address _receiver
    ) public {
        aToken.burn(msg.sender, _amount);
        ERC20(_asset).transfer(_receiver, _amount);
    }

    // Mints recipient new tokens based on current aToken balance
    // to simulate new yield accrued
    // _yield is fraction > 1 using SCALE as denominator
    function simulateYield(address _recipient, uint256 _yield) public {
        uint256 balanceBefore = aToken.balanceOf(_recipient);
        uint256 balanceAfter = (balanceBefore * _yield) / SCALE;
        aToken.mint(_recipient, balanceAfter - balanceBefore);
    }
}
