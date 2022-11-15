// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IATokenVault {
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeTaken(uint256 shares);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event AavePoolUpdated(address newAavePool);
    event YieldAccrued(uint256 totalNewYield, uint256 newFeesFromYield);
    event AaveRewardsClaimed(address to, address[] rewardsList, uint256[] claimedAmounts);

    error FeeTooHigh();
    error InsufficientFees();
    error AssetNotSupported();
    error CannotSendRewardsToZeroAddress();
}
