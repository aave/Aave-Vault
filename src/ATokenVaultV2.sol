// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {ATokenVault} from "./ATokenVault.sol";

/**
 * @title ATokenVaultV2
 * @author Aave Protocol
 * @notice An ERC-4626 vault for Aave V3, with support to add a fee on yield earned.
 */
contract ATokenVaultV2 is ATokenVault {
    /**
     * @dev Constructor.
     * @param underlying The underlying ERC20 asset which can be supplied to Aave
     * @param referralCode The Aave referral code to use for deposits from this vault
     * @param poolAddressesProvider The address of the Aave v3 Pool Addresses Provider
     */
    constructor(
        address underlying,
        uint16 referralCode,
        IPoolAddressesProvider poolAddressesProvider
    ) ATokenVault(underlying, referralCode, poolAddressesProvider) {
        // Intentionally left blank
    }

    /**
     * @dev Re-initializes the vault
     */
    function initializeV2() external reinitializer(2) {
        // Reset deprecated cap
        _s.__deprecated_gap = 0;
    }
}
