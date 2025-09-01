// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ATokenVaultRevenueSplitterOwner} from "./ATokenVaultRevenueSplitterOwner.sol";
import {ImmutableATokenVault} from "./ImmutableATokenVault.sol";
import {SSTORE2} from "@solmate/utils/SSTORE2.sol";
import {Create2} from "@openzeppelin/utils/Create2.sol";
import {LibZip} from "@solady/utils/LibZip.sol";

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

    address immutable public VAULT_CREATION_CODE_SSTORE2_POINTER;

    uint256 internal _nextSalt;

    constructor() {
        VAULT_CREATION_CODE_SSTORE2_POINTER = SSTORE2.write(LibZip.flzCompress(type(ImmutableATokenVault).creationCode));
    }

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

        bytes memory vaultInitCode = abi.encodePacked(
            LibZip.flzDecompress(SSTORE2.read(VAULT_CREATION_CODE_SSTORE2_POINTER)),
            abi.encode(
                params.underlying,
                params.referralCode,
                params.poolAddressesProvider,
                address(this),
                params.initialFee,
                params.shareName,
                params.shareSymbol,
                params.initialLockDeposit
            )
        );

        address vaultAddress = _computeVaultAddress(vaultInitCode, salt);

        IERC20(params.underlying).safeApprove(vaultAddress, params.initialLockDeposit);

        _deployVault(vaultInitCode, salt);

        address owner = params.owner;
        if (params.revenueRecipients.length > 0) {
            owner = _deployRevenueSplitterOwner(vaultAddress, params.owner, params.revenueRecipients);
        }
        ImmutableATokenVault(vaultAddress).transferOwnership(owner);

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

    function _computeVaultAddress(bytes memory vaultInitCode, bytes32 salt) internal view returns (address) {
        return Create2.computeAddress(salt, keccak256(vaultInitCode));
    }

    function _deployVault(bytes memory vaultInitCode, bytes32 salt) internal returns (address) {
        address vaultAddress;
        assembly {
            vaultAddress := create2(0, add(vaultInitCode, 32), mload(vaultInitCode), salt)
            // If the deployment fails, revert bubbling up the error
            if iszero(vaultAddress) {
                let returnDataSize := returndatasize()
                returndatacopy(0, 0, returnDataSize)
                revert(0, returnDataSize)
            }
        }
        return vaultAddress;
    }
}
