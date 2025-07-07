// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ATokenVault} from "./ATokenVault.sol";

/**
 * @title ATokenVaultFactory
 * @author Aave Protocol
 * @notice Factory contract for deploying ATokenVault instances
 */
contract ATokenVaultFactory {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emitted when a new vault is deployed
     * @param vault The address of the deployed vault proxy
     * @param implementation The address of the vault implementation
     * @param underlying The underlying asset address
     * @param deployer The address that deployed the vault
     * @param owner The owner of the vault
     */
    event VaultDeployed(
        address indexed vault,
        address indexed implementation,
        address indexed underlying,
        address deployer,
        address owner,
        uint16 referralCode,
        address poolAddressesProvider
    );

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Array of all deployed vaults
    address[] public allVaults;

    /// @notice Mapping from underlying asset to deployed vaults
    mapping(address => address[]) public vaultsByUnderlying;

    /// @notice Mapping from deployer to deployed vaults
    mapping(address => address[]) public vaultsByDeployer;

    /// @notice Mapping to check if a vault was deployed by this factory
    mapping(address => bool) public isVaultDeployed;

    /// @notice Counter for unique salt generation
    uint256 private deploymentCounter;

    /// @notice Proxy admin address for all deployed vaults
    address public immutable PROXY_ADMIN;

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
     * @param proxyAdmin The address that will be the admin of all deployed proxies
     */
    constructor(address proxyAdmin) {
        require(proxyAdmin != address(0), "ZERO_ADDRESS_NOT_VALID");
        PROXY_ADMIN = proxyAdmin;
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

        // Transfer the initial lock deposit from caller to this contract
        IERC20(params.underlying).transferFrom(
            msg.sender,
            address(this),
            params.initialLockDeposit
        );

        uint256 currentCounter = deploymentCounter++;

        bytes32 salt = keccak256(abi.encodePacked(
            params.underlying,
            params.referralCode,
            address(params.poolAddressesProvider),
            msg.sender,
            block.timestamp,
            currentCounter
        ));

        address implementation = address(new ATokenVault{salt: salt}(
            params.underlying,
            params.referralCode,
            params.poolAddressesProvider
        ));

        vault = address(new TransparentUpgradeableProxy{salt: salt}(
            implementation,
            PROXY_ADMIN,
            ""
        ));

        IERC20(params.underlying).approve(vault, params.initialLockDeposit);

        // Initialize the proxy (this will trigger the token transfer)
        ATokenVault(vault).initialize(
            params.owner,
            params.initialFee,
            params.shareName,
            params.shareSymbol,
            params.initialLockDeposit
        );

        allVaults.push(vault);
        vaultsByUnderlying[params.underlying].push(vault);
        vaultsByDeployer[msg.sender].push(vault);
        isVaultDeployed[vault] = true;

        emit VaultDeployed(
            vault,
            implementation,
            params.underlying,
            msg.sender,
            params.owner,
            params.referralCode,
            address(params.poolAddressesProvider)
        );
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the total number of deployed vaults
     * @return The total number of vaults
     */
    function getAllVaultsLength() external view returns (uint256) {
        return allVaults.length;
    }

    /**
     * @notice Get all deployed vaults
     * @return Array of all vault addresses
     */
    function getAllVaults() external view returns (address[] memory) {
        return allVaults;
    }

    /**
     * @notice Get vaults by underlying asset
     * @param underlying The underlying asset address
     * @return Array of vault addresses for the underlying asset
     */
    function getVaultsByUnderlying(address underlying) external view returns (address[] memory) {
        return vaultsByUnderlying[underlying];
    }

    /**
     * @notice Get vaults by deployer
     * @param deployer The deployer address
     * @return Array of vault addresses deployed by the deployer
     */
    function getVaultsByDeployer(address deployer) external view returns (address[] memory) {
        return vaultsByDeployer[deployer];
    }

    /**
     * @notice Get vault deployment info
     * @param vaultIndex The index of the vault in allVaults array
     * @return vault The vault address
     * @return underlying The underlying asset
     */
    function getVaultInfo(uint256 vaultIndex) external view returns (
        address vault,
        address underlying
    ) {
        require(vaultIndex < allVaults.length, "INVALID_VAULT_INDEX");
        vault = allVaults[vaultIndex];
        ATokenVault vaultContract = ATokenVault(vault);
        underlying = address(vaultContract.UNDERLYING());
    }

    /**
     * @notice Check if a vault was deployed by this factory
     * @param vault The vault address to check
     * @return True if the vault was deployed by this factory
     */
    function isDeployedVault(address vault) external view returns (bool) {
        return isVaultDeployed[vault];
    }
}