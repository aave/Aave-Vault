// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ATokenVault} from "./ATokenVault.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ProxyAdmin} from "@openzeppelin/proxy/transparent/ProxyAdmin.sol";

/**
 * @title ATokenVaultImplDeploymentLib
 * @author Aave Labs
 * @notice Library that handles the deployment of the ATokenVault implementation contract
 * @dev This library is a helper to avoid holding the ATokenVault bytecode in the factory contract avoiding exceeding
 *      the contract size limit.
 */
library ATokenVaultImplDeploymentLib {
    function deployVaultImpl(
        address underlying,
        uint16 referralCode,
        IPoolAddressesProvider poolAddressesProvider
    ) external returns (address vault) {
        return address(new ATokenVault(
            underlying,
            referralCode,
            poolAddressesProvider
        ));
    }
}

/**
 * @title ATokenVaultFactory
 * @author Aave Labs
 * @notice Factory contract for deploying ATokenVault instances
 */
contract ATokenVaultFactory {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emitted when a new vault is deployed
     * @param vault The address of the deployed vault proxy
     * @param implementation The address of the vault implementation
     * @param underlying The underlying asset address
     * @param deployer The address that deployed the vault
     * @param params The parameters used to deploy the vault
     */
    event VaultDeployed(
        address indexed vault,
        address indexed implementation,
        address indexed underlying,
        address deployer,
        VaultParams params
    );

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proxy admin address for all deployed vaults, with renounced ownership.
    /// @dev Future version will deploy a plain immutable vault without proxy.
    address internal immutable RENOUNCED_PROXY_ADMIN;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

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
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Constructor
     * @param proxyAdmin The address that will be the admin of all deployed proxies. Must have renounced ownership.
     */
    constructor(address proxyAdmin) {
        RENOUNCED_PROXY_ADMIN = proxyAdmin;
        require(ProxyAdmin(proxyAdmin).owner() == address(0), "PROXY_ADMIN_OWNERSHIP_NOT_RENOUNCED");
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploy a new ATokenVault with the given parameters
     * @param params All parameters needed for vault deployment and initialization
     * @return vault The address of the deployed vault proxy
     */
    function deployVault(VaultParams memory params) public returns (address vault) {
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

        address implementation = ATokenVaultImplDeploymentLib.deployVaultImpl(
            params.underlying,
            params.referralCode,
            params.poolAddressesProvider
        );

        vault = address(new TransparentUpgradeableProxy(
            implementation,
            RENOUNCED_PROXY_ADMIN,
            ""
        ));

        IERC20(params.underlying).safeApprove(vault, params.initialLockDeposit);

        ATokenVault(vault).initialize(
            params.owner,
            params.initialFee,
            params.shareName,
            params.shareSymbol,
            params.initialLockDeposit
        );

        emit VaultDeployed(
            vault,
            implementation,
            params.underlying,
            msg.sender,
            params
        );
    }
}
