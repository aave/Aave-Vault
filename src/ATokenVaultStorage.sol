// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @title ATokenVaultStorage
 * @author Aave Protocol
 * @notice Contains storage variables for the ATokenVault.
 */
abstract contract ATokenVaultStorage {
    mapping(address => uint256) internal _sigNonces;

    // timestamp of last accrueYield action
    uint40 internal _lastUpdated;

    // total aToken incl. fees
    uint128 internal _lastVaultBalance;

    // as a fraction of 1e18
    uint64 internal _fee;

    // fees accrued since last updated
    uint128 internal _accumulatedFees;
}
