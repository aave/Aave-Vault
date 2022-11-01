// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {DataTypes} from "aave/protocol/libraries/types/DataTypes.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockAToken} from "./MockAToken.sol";

contract MockAavePool {
    uint256 constant SCALE = 1e18;

    MockAToken public aToken;

    constructor(MockAToken _aToken) {
        aToken = _aToken;
    }

    function getReserveData(address _reserve) public returns (DataTypes.ReserveData memory) {
        return
            DataTypes.ReserveData({
                //stores the reserve configuration
                configuration: DataTypes.ReserveConfigurationMap({data: 0}),
                //the liquidity index. Expressed in ray
                liquidityIndex: 0,
                //the current supply rate. Expressed in ray
                currentLiquidityRate: 0,
                //variable borrow index. Expressed in ray
                variableBorrowIndex: 0,
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
