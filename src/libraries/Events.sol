// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

library Events {
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeTaken(uint256 shares);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event YieldAccrued(uint256 totalNewYield, uint256 newFeesFromYield);
    event AaveRewardsClaimed(address indexed to, address[] rewardsList, uint256[] claimedAmounts);
    event EmergencyRescue(address indexed token, address indexed to, uint256 amount);
}
