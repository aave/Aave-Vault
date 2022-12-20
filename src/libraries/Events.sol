// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

library Events {
    event FeeUpdated(uint64 oldFee, uint64 newFee);
    event FeeTaken(uint256 shares);
    event FeesWithdrawn(address indexed to, uint256 amount, uint256 newVaultBalance, uint256 newTotalFeesAccrued);
    event YieldAccrued(uint256 totalNewYield, uint256 newFeesFromYield, uint256 newVaultBalance);
    event AaveRewardsClaimed(address indexed to, address[] rewardsList, uint256[] claimedAmounts);
    event EmergencyRescue(address indexed token, address indexed to, uint256 amount);
}
