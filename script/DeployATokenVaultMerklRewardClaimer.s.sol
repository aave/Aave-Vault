// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20Upgradeable} from "@openzeppelin-upgradeable/interfaces/IERC20Upgradeable.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";

import { ATokenVault } from "src/ATokenVault.sol";
import { ATokenVaultMerklRewardClaimer } from "src/ATokenVaultMerklRewardClaimer.sol";

contract DeployATokenVaultMerklRewardClaimer is Script {
    // DEPLOYMENT PARAMETERS - CHANGE THESE FOR YOUR VAULT
    // ===================================================
    address constant DEPLOYER_ADDRESS = address(0); // Address of the deployer
    address constant UNDERLYING_ASSET_ADDRESS = address(0); // Underlying asset listed in the Aave Protocol
    uint16 constant REFERRAL_CODE = 0; // Referral code to use
    address constant AAVE_POOL_ADDRESSES_PROVIDER_ADDRESS = address(0); // PoolAddressesProvider contract of the Aave Pool
    address constant PROXY_ADMIN_ADDRESS = address(0); // Address of the proxy admin
    address constant OWNER_ADDRESS = address(0); // Address of the vault owner
    string constant SHARE_NAME = ""; // Name of the token shares
    string constant SHARE_SYMBOL = ""; // Symbol of the token shares
    uint256 constant FEE = 0; // Vault Fee bps in wad (e.g. 0.1e18 results in 10%)
    uint256 constant INITIAL_LOCK_DEPOSIT = 0; // Initial deposit on behalf of the vault
    address constant MERKL_DISTRIBUTOR_ADDRESS = address(0); // Address of the Merkl distributor contract
    // ===================================================

    
    function run() external {
        require(DEPLOYER_ADDRESS != address(0), "DEPLOYER_ADDRESS is not set");
        require(UNDERLYING_ASSET_ADDRESS != address(0), "UNDERLYING_ASSET_ADDRESS is not set");
        require(AAVE_POOL_ADDRESSES_PROVIDER_ADDRESS != address(0), "AAVE_POOL_ADDRESSES_PROVIDER_ADDRESS is not set");
        require(PROXY_ADMIN_ADDRESS != address(0), "PROXY_ADMIN_ADDRESS is not set");
        require(OWNER_ADDRESS != address(0), "OWNER_ADDRESS is not set");
        require(bytes(SHARE_NAME).length > 0, "SHARE_NAME is not set");
        require(bytes(SHARE_SYMBOL).length > 0, "SHARE_SYMBOL is not set");
        require(FEE != 0, "FEE is not set. Comment this requirement out if you want a zero fee vault.");
        require(INITIAL_LOCK_DEPOSIT != 0, "INITIAL_LOCK_DEPOSIT is not set");
        require(MERKL_DISTRIBUTOR_ADDRESS != address(0), "MERKL_DISTRIBUTOR_ADDRESS is not set. Comment this requirement out if you want to set it later.");

        vm.startBroadcast(DEPLOYER_ADDRESS);

        // Deploy the implementation, which disables initializers on construction
        ATokenVaultMerklRewardClaimer vault = new ATokenVaultMerklRewardClaimer(
            UNDERLYING_ASSET_ADDRESS,
            REFERRAL_CODE,
            IPoolAddressesProvider(AAVE_POOL_ADDRESSES_PROVIDER_ADDRESS)
        );
        console.log("Vault impl deployed at: ", address(vault));

        console.log("Deploying proxy...");
        // Encode the initializer call
        bytes memory initData = abi.encodeWithSelector(
            ATokenVault.initialize.selector,
            OWNER_ADDRESS,
            FEE,
            SHARE_NAME,
            SHARE_SYMBOL,
            INITIAL_LOCK_DEPOSIT
        );
        console.logBytes(initData);

        address proxyAddress = computeCreateAddress(DEPLOYER_ADDRESS, vm.getNonce(DEPLOYER_ADDRESS) + 1);
        IERC20Upgradeable(UNDERLYING_ASSET_ADDRESS).approve(proxyAddress, INITIAL_LOCK_DEPOSIT);
        console.log("Precomputed proxy address: ", proxyAddress);

        // Deploy and initialize the proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(vault), PROXY_ADMIN_ADDRESS, initData);
        console.log("Vault proxy deployed and initialized at: ", address(proxy));

        vault = ATokenVaultMerklRewardClaimer(address(proxy));
        if (MERKL_DISTRIBUTOR_ADDRESS != address(0)) {
            vault.setMerklDistributor(MERKL_DISTRIBUTOR_ADDRESS);
        }
        vm.stopBroadcast();

        console.log("\nVault data:");
        console.log("Pool Addresses Provider:", address(vault.POOL_ADDRESSES_PROVIDER()));
        console.log("Referral Code:", vault.REFERRAL_CODE());
        console.log("Underlying:", address(vault.UNDERLYING()));
        console.log("aToken:", address(vault.ATOKEN()));
        console.log("Name:", vault.name());
        console.log("Symbol:", vault.symbol());
        console.log("Owner:", vault.owner());
        console.log("Fee:", vault.getFee());
        console.log("Merkl Distributor:", vault.getMerklDistributor());
    }
}
