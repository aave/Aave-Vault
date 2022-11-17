// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

library Events {
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeTaken(uint256 shares);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event AavePoolUpdated(address newAavePool);
    event YieldAccrued(uint256 totalNewYield, uint256 newFeesFromYield);
}
