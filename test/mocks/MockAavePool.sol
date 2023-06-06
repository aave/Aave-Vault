// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {MockAToken} from "./MockAToken.sol";

// NOTE: Yield Simulation Design
// To mock yield accrual, we increase the vault's aToken asset balance.
// But, this will lead to scenarios where there are more aTokens to redeem
// Than there are underlying assets in this mock pool.
// As such, avoid using the deal cheatcode in Foundry and instead
// implement utility functions which retain 1:1 asset:aToken parity

contract MockAavePool {
    uint256 constant SCALE = 1e18;

    MockAToken public aToken;

    uint256 public reserveConfigMap;

    constructor(MockAToken _aToken) {
        aToken = _aToken;
    }

    // For mock test purposes
    function setReserveConfigMap(uint256 _reserveConfigMap) public {
        reserveConfigMap = _reserveConfigMap;
    }

    function getReserveData(address) public view returns (DataTypes.ReserveData memory) {
        return
            DataTypes.ReserveData({
                //stores the reserve configuration
                configuration: DataTypes.ReserveConfigurationMap({data: reserveConfigMap}),
                //the liquidity index. Expressed in ray
                liquidityIndex: 1e27,
                //the current supply rate. Expressed in ray
                currentLiquidityRate: 0,
                //variable borrow index. Expressed in ray
                variableBorrowIndex: 1e27,
                //the current variable borrow rate. Expressed in ray
                currentVariableBorrowRate: 0,
                //the current stable borrow rate. Expressed in ray
                currentStableBorrowRate: 0,
                //timestamp of last update
                lastUpdateTimestamp: 0,
                //the id of the reserve. Represents the position in the list of the active reserves
                id: 0,
                //aToken address
                aTokenAddress: address(aToken),
                //stableDebtToken address
                stableDebtTokenAddress: address(0),
                //variableDebtToken address
                variableDebtTokenAddress: address(0),
                //address of the interest rate strategy
                interestRateStrategyAddress: address(0),
                //the current treasury balance, scaled
                accruedToTreasury: 0,
                //the outstanding unbacked aTokens minted through the bridging feature
                unbacked: 0,
                //the outstanding debt borrowed against this asset in isolation mode
                isolationModeTotalDebt: 0
            });
    }

    function supply(address _asset, uint256 _amount, address _onBehalfOf, uint16) public {
        ERC20(_asset).transferFrom(msg.sender, address(this), _amount);
        aToken.mint(address(this), _onBehalfOf, _amount, 0);
        ERC20(_asset).transfer(address(aToken), _amount);
    }

    function withdraw(address _asset, uint256 _amount, address _receiver) public returns (uint256) {
        aToken.burn(msg.sender, _receiver, _amount, 0);
        return _amount;
    }

    // Mints recipient new tokens based on current aToken balance
    // to simulate new yield accrued
    // _yield is fraction > 1 using SCALE as denominator
    function simulateYield(address _recipient, uint256 _yield) public {
        uint256 balanceBefore = aToken.balanceOf(_recipient);
        uint256 balanceAfter = (balanceBefore * _yield) / SCALE;

        aToken.mint(address(this), _recipient, balanceAfter - balanceBefore, 0);
    }
}
