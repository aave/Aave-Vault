// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20Upgradeable} from "@openzeppelin-upgradeable/interfaces/IERC20Upgradeable.sol";

import "../src/ATokenVault.sol";

contract Deploy is Script {
    // DEPLOYMENT PARAMETERS - CHANGE THESE FOR YOUR VAULT
    // ===================================================
    address UNDERLYING_ASSET_ADDRESS = address(0); // Underlying asset listed in the Aave Protocol
    uint16 REFERRAL_CODE = 0; // Referral code to use
    address AAVE_POOL_ADDRESSES_PROVIDER_ADDRESS = address(0); // PoolAddressesProvider contract of the Aave Pool
    address constant PROXY_ADMIN_ADDRESS = address(0); // Address of the proxy admin
    address constant OWNER_ADDRESS = address(0); // Address of the vault owner
    string constant SHARE_NAME = "Wrapped aDAI"; // Name of the token shares
    string constant SHARE_SYMBOL = "waDAI"; // Symbol of the token shares
    uint256 constant FEE = 0.1e18; // Vault Fee bps in wad (e.g. 0.1e18 results in 10%)
    uint256 constant INITIAL_LOCK_DEPOSIT = 10e18; // Initial deposit on behalf of the vault
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
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", getChainId());
        console.log("Deploying vault...");

        require(
            INITIAL_LOCK_DEPOSIT != 0,
            "Initial deposit not set. This prevents a frontrunning attack, please set a non-trivial initial deposit."
        );

        vm.startBroadcast(deployerPrivateKey);

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
