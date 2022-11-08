// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IATokenVault {
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeTaken(uint256 shares);
    event FeesWithdrawn(uint256 amount, address to);
    event AavePoolUpdated(address newAavePool);
    event YieldAccrued(uint256 totalNewYield, uint256 newFeesFromYield);

    error FeeTooHigh();
    error InsufficientFees();
}
