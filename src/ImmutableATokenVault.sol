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
        _initialize(
            underlying,
            owner,
            initialFee,
            shareName,
            shareSymbol,
            initialLockDeposit
        );
    }

    /**
     * @dev Initializes the contract given that the base contract, ATokenVault, uses upgradable contracts.
     */
    function _initialize(
        address underlying,
        address owner,
        uint256 initialFee,
        string memory shareName,
        string memory shareSymbol,
        uint256 initialLockDeposit
    ) internal virtual initializer {
        require(owner != address(0), "ZERO_ADDRESS_NOT_VALID");
        require(initialLockDeposit != 0, "ZERO_INITIAL_LOCK_DEPOSIT");
        _transferOwnership(owner);
        __ERC4626_init(IERC20Upgradeable(underlying));
        __ERC20_init(shareName, shareSymbol);
        __EIP712_init(shareName, "1");
        _setFee(initialFee);
        IERC20Upgradeable(underlying).safeApprove(address(AAVE_POOL), type(uint256).max);
        _handleDeposit(initialLockDeposit, address(this), msg.sender, false);
    }

    /**
     * @dev Overrides the base contract's `_disableInitializers` function to do nothing.
     * This turns the `_disableInitializers` call in ATokenVault's constructor ineffective,
     * allowing initialization at the ImmutableATokenVault's constructor.
     */
    function _disableInitializers() internal virtual override { }
}
