// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

import {SafeERC20Upgradeable} from "@openzeppelin-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin-upgradeable/interfaces/IERC20Upgradeable.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {ATokenVault} from "./ATokenVault.sol";

/**
 * @title ImmutableATokenVault
 * @author Aave Labs
 * @notice An immutable ERC-4626 vault for Aave V3, with support to add a fee on yield earned.
 */
contract ImmutableATokenVault is ATokenVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev Constructor.
     * @param underlying The underlying ERC-20 asset.
     * @param referralCode The Aave referral code to use for deposits from this vault.
     * @param poolAddressesProvider The address of the Aave v3 Pool Addresses Provider.
     * @param owner The owner of the vault to set.
     * @param initialFee The initial fee to set, expressed in wad, where 1e18 is 100%.
     * @param shareName The name to set for this vault's shares.
     * @param shareSymbol The symbol to set for this vault's shares.
     * @param initialLockDeposit The initial amount of underlying assets to deposit. Required to prevent a frontrunning
     * attack (in underlying tokens). Note that care should be taken to provide a non-trivial amount, but this depends
     * on the underlying asset's decimals.
     */
    constructor(
        address underlying,
        uint16 referralCode,
        IPoolAddressesProvider poolAddressesProvider,
        address owner,
        uint256 initialFee,
        string memory shareName,
        string memory shareSymbol,
        uint256 initialLockDeposit
    ) ATokenVault(underlying, referralCode, poolAddressesProvider) {
        // Initializer was disabled by the constructor of ATokenVault, the base contract; we re-enable it back.
        _reEnableInitializers();

        require(owner != address(0), "ZERO_ADDRESS_NOT_VALID");
        require(initialLockDeposit != 0, "ZERO_INITIAL_LOCK_DEPOSIT");
        _transferOwnership(owner);
        __ERC4626_init(IERC20Upgradeable(underlying));
        __ERC20_init(shareName, shareSymbol);
        __EIP712_init(shareName, "1");
        _setFee(initialFee);
        IERC20Upgradeable(underlying).safeApprove(address(AAVE_POOL), type(uint256).max);
        _handleDeposit(initialLockDeposit, address(this), msg.sender, false);

        // Sets the `_initializing` flag to false.
        _endInitialization();
        // Disables initializers again.
        _disableInitializers();
    }

    function _reEnableInitializers() internal {
        bytes32 valueAtSlot0;

        // Load the value located at storage slot 0 into `valueAtSlot0` variable.
        assembly {
            valueAtSlot0 := sload(0x00)
        }

        // Set the first and second bytes to 0x01, without altering any other bytes:
        // Step I: Clear the first two bytes by setting them to 0x00.
        valueAtSlot0 &= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; 
        // Step II: Set the first two bytes to 0x01.
        valueAtSlot0 |= 0x0000000000000000000000000000000000000000000000000000000000000101;

        // The first byte corresponds to the `_initialized` uint8 flag.
        // The second byte corresponds to the `_initializing` bool flag.
        // So this was equivalent to `_initialized = 1` and `_initializing = true`, which is what the `initializer()`
        // modifier does at the beginning.

        // Store the altered value back into storage slot 0.
        assembly {
            sstore(0x00, valueAtSlot0)
        }
    }

    function _endInitialization() internal {
        bytes32 valueAtSlot0;

        // Load the value located at storage slot 0 into `valueAtSlot0` variable.
        assembly {
            valueAtSlot0 := sload(0x00)
        }

        // Set the second byte to 0x00, without altering any other bytes.
        valueAtSlot0 &= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FF;

        // The second byte corresponds to the `_initializing` bool flag.
        // So this was equivalent to `_initializing = true`, which is what the `initializer()` modifier does
        // after initialization is complete.

        // Store the altered value back into storage slot 0.
        assembly {
            sstore(0x00, valueAtSlot0)
        }
    }
}
