// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ATokenVaultRevenueSplitterOwner} from "./ATokenVaultRevenueSplitterOwner.sol";
import {ImmutableATokenVault} from "./ImmutableATokenVault.sol";
import {CREATE3} from "@solmate/utils/CREATE3.sol";

/**
 * @dev Struct containing constructor parameters for vault deployment
 */
struct VaultParams {
    address underlying;
    uint16 referralCode;
    IPoolAddressesProvider poolAddressesProvider;
    address owner;
    uint256 initialFee;
    string shareName;
    string shareSymbol;
    uint256 initialLockDeposit;
    ATokenVaultRevenueSplitterOwner.Recipient[] revenueRecipients;
}

/**
 * @title ATokenVaultDeploymentLib
 * @author Aave Labs
 * @notice Library that handles the deployment of the ATokenVault implementation contract
 * @dev This library is a helper to avoid holding the ATokenVault bytecode in the factory contract avoiding exceeding
 *      the contract size limit.
 */
library ATokenVaultDeploymentLib {
    function deployVault(
        bytes32 salt,
        address vaultOwner,
        VaultParams memory params
    ) external returns (address vault) {
        return CREATE3.deploy(
            salt,
            abi.encodePacked(
                type(ImmutableATokenVault).creationCode,
                abi.encode(
                    params.underlying,
                    params.referralCode,
                    params.poolAddressesProvider,
                    vaultOwner,
                    params.initialFee,
                    params.shareName,
                    params.shareSymbol,
                    params.initialLockDeposit
                )
            ),
            0
        );
    }
}

/**
 * @title ATokenVaultFactory
 * @author Aave Labs
 * @notice Factory contract for deploying ATokenVault instances
 */
contract ATokenVaultFactory {
    using SafeERC20 for IERC20;

    /**
     * @dev Emitted when a new vault is deployed
     * @param vault The address of the deployed vault
     * @param underlying The underlying asset address
     * @param deployer The address that deployed the vault
     * @param params The parameters used to deploy the vault
     */
    event VaultDeployed(
        address indexed vault,
        address indexed underlying,
        address deployer,
        VaultParams params
    );

    /**
     * @dev Emitted when a new revenue splitter owner is deployed
     * @param revenueSplitterOwner The address of the deployed revenue splitter owner
     * @param vault The address of the vault to split the revenue from
     * @param owner The address of the owner of the revenue splitter, effective owner of the vault
     * @param revenueRecipients The recipients of the revenue
     */
    event RevenueSplitterOwnerDeployed(
        address indexed revenueSplitterOwner,
        address indexed vault,
        address indexed owner,
        ATokenVaultRevenueSplitterOwner.Recipient[] revenueRecipients
    );

    uint256 internal _nextSalt;

    /**
     * @notice Deploys a new ATokenVault with the given parameters
     * @param params All parameters needed for vault deployment and initialization
     * @return vault The address of the deployed vault proxy
     */
    function deployVault(VaultParams memory params) public returns (address) {
        require(params.underlying != address(0), "ZERO_ADDRESS_NOT_VALID");
        require(address(params.poolAddressesProvider) != address(0), "ZERO_ADDRESS_NOT_VALID");
        require(params.owner != address(0), "ZERO_ADDRESS_NOT_VALID");
        require(params.initialLockDeposit > 0, "ZERO_INITIAL_LOCK_DEPOSIT");
        require(bytes(params.shareName).length > 0, "EMPTY_SHARE_NAME");
        require(bytes(params.shareSymbol).length > 0, "EMPTY_SHARE_SYMBOL");

        IERC20(params.underlying).safeTransferFrom(
            msg.sender,
            address(this),
            params.initialLockDeposit
        );

        bytes32 salt = bytes32(_nextSalt++);

        address vaultAddress = CREATE3.getDeployed(salt);

        address owner = params.owner;
        if (params.revenueRecipients.length > 0) {
            owner = _deployRevenueSplitterOwner(vaultAddress, params.owner, params.revenueRecipients);
        }

        IERC20(params.underlying).approve(vaultAddress, params.initialLockDeposit);

        ATokenVaultDeploymentLib.deployVault(salt, owner, params);

        emit VaultDeployed(
            vaultAddress,
            params.underlying,
            msg.sender,
            params
        );

        return vaultAddress;
    }

    /**
     * @notice Deploys a new ATokenVaultRevenueSplitterOwner with the given parameters
     * @param vaultAddress The address of the vault to split the revenue from
     * @param owner The address of the owner of the revenue splitter, effective owner of the vault
     * @param revenueRecipients The recipients of the revenue
     * @return revenueSplitter The address of the deployed revenue splitter
     */
    function deployRevenueSplitterOwner(
        address vaultAddress,
        address owner,
        ATokenVaultRevenueSplitterOwner.Recipient[] memory revenueRecipients
    ) external returns (address) {
        return _deployRevenueSplitterOwner(vaultAddress, owner, revenueRecipients);
    }

    function _deployRevenueSplitterOwner(
        address vaultAddress,
        address owner,
        ATokenVaultRevenueSplitterOwner.Recipient[] memory revenueRecipients
    ) internal returns (address) {
        address revenueSplitter = address(new ATokenVaultRevenueSplitterOwner(vaultAddress, owner, revenueRecipients));
        emit RevenueSplitterOwnerDeployed(revenueSplitter, vaultAddress, owner, revenueRecipients);
        return revenueSplitter;
    }
}
