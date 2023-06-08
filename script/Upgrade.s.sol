// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";

import {ATokenVaultV2} from "../src/ATokenVaultV2.sol";

contract Upgrade is Script {
    // DEPLOYMENT PARAMETERS - CHANGE THESE FOR YOUR VAULT
    // ===================================================
    address constant VAULT_ADDRESS = address(0); // Vault to upgrade
    address constant UNDERLYING_ASSET_ADDRESS = address(0); // Underlying asset listed in the Aave Protocol
    uint16 constant REFERRAL_CODE = 0; // Referral code to use
    address constant AAVE_POOL_ADDRESSES_PROVIDER_ADDRESS = address(0); // PoolAddressesProvider contract of the Aave Pool
    // ===================================================

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

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        ATokenVaultV2 newImple = new ATokenVaultV2(
            UNDERLYING_ASSET_ADDRESS,
            REFERRAL_CODE,
            IPoolAddressesProvider(AAVE_POOL_ADDRESSES_PROVIDER_ADDRESS)
        );
        console.log("VaultV2 impl deployed at: ", address(newImple));

        console.log("Initializing...");
        // Encode the initializer call
        bytes memory data = abi.encodeWithSelector(ATokenVaultV2.initializeV2.selector);
        console.logBytes(data);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(VAULT_ADDRESS));
        proxy.upgradeToAndCall(address(newImple), data);

        vm.stopBroadcast();

        console.log("Vault proxy upgraded at: ", address(proxy), " with implementation: ", address(newImple));
    }
}
