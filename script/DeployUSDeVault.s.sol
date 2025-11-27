// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20Upgradeable} from "@openzeppelin-upgradeable/interfaces/IERC20Upgradeable.sol";

import "../src/ATokenVault.sol";

contract DeployUSDeVault is Script {
    // DEPLOYMENT PARAMETERS - CHANGE THESE FOR YOUR VAULT
    // ===================================================
    address UNDERLYING_ASSET_ADDRESS = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3; // USDe
    uint16 REFERRAL_CODE = 0; // Referral code to use
    address AAVE_POOL_ADDRESSES_PROVIDER_ADDRESS = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e; // PoolAddressesProvider contract of the Aave Pool
    address constant PROXY_ADMIN_ADDRESS = 0xf817cb3092179083c48c014688D98B72fB61464f; // Timelock
    address constant OWNER_ADDRESS = 0xf817cb3092179083c48c014688D98B72fB61464f; // Timelock
    string constant SHARE_NAME = "Wrapped aUSDe"; // Name of the token shares
    string constant SHARE_SYMBOL = "waUSDe"; // Symbol of the token shares
    uint256 constant FEE = 0; // Vault Fee bps in wad (e.g. 0.1e18 results in 10%)
    uint256 constant INITIAL_LOCK_DEPOSIT = 1e18; // Initial deposit on behalf of the vault
    // ===================================================

    ATokenVault public vault;

    function getChainId() public view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    function run() external {
        // require(vm.envExists("DEPLOYER_ADDRESS"), "DEPLOYER_ADDRESS env var not set");
        address deployerAddress = vm.envAddress("DEPLOYER_ADDRESS");

        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", getChainId());
        console.log("Deploying vault...");

        require(
            INITIAL_LOCK_DEPOSIT != 0,
            "Initial deposit not set. This prevents a frontrunning attack, please set a non-trivial initial deposit."
        );

        vm.startBroadcast(deployerAddress);

        // Deploy the implementation, which disables initializers on construction
        vault = new ATokenVault(
            UNDERLYING_ASSET_ADDRESS,
            REFERRAL_CODE,
            IPoolAddressesProvider(AAVE_POOL_ADDRESSES_PROVIDER_ADDRESS)
        );
        console.log("Vault impl deployed at: ", address(vault));

        console.log("Deploying proxy...");
        // Encode the initializer call
        bytes memory data = abi.encodeWithSelector(
            ATokenVault.initialize.selector,
            OWNER_ADDRESS,
            FEE,
            SHARE_NAME,
            SHARE_SYMBOL,
            INITIAL_LOCK_DEPOSIT
        );
        console.logBytes(data);

        address proxyAddr = computeCreateAddress(deployerAddress, vm.getNonce(deployerAddress) + 1);
        IERC20Upgradeable(UNDERLYING_ASSET_ADDRESS).approve(proxyAddr, INITIAL_LOCK_DEPOSIT);
        console.log("Precomputed proxy address: ", proxyAddr);
        console.log("Allowance for proxy: ", IERC20Upgradeable(UNDERLYING_ASSET_ADDRESS).allowance(deployerAddress, proxyAddr));

        // Deploy and initialize the proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(vault), PROXY_ADMIN_ADDRESS, data);
        console.log("Vault proxy deployed and initialized at: ", address(proxy));

        vm.stopBroadcast();

        console.log("\nVault data:");
        vault = ATokenVault(address(proxy));
        console.log("POOL_ADDRESSES_PROVIDER:", address(vault.POOL_ADDRESSES_PROVIDER()));
        console.log("REFERRAL_CODE:", vault.REFERRAL_CODE());
        console.log("UNDERLYING:", address(vault.UNDERLYING()));
        console.log("ATOKEN:", address(vault.ATOKEN()));
        console.log("Name:", vault.name());
        console.log("Symbol:", vault.symbol());
        console.log("Owner:", vault.owner());
        console.log("Fee:", vault.getFee());
    }
}
