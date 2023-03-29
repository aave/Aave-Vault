// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";

import "../src/ATokenVault.sol";

contract Deploy is Script {
    // MUMBAI TESTNET ADDRESSES
    address constant DAI_MUMBAI = 0x9A753f0F7886C9fbF63cF59D0D4423C5eFaCE95B;
    address constant POOL_ADDRESS_PROVIDER_MUMBAI = 0x5343b5bA672Ae99d627A1C87866b8E53F47Db2E6;
    address constant REWARDS_CONTROLLER_MUMBAI = address(0);

    // POLYGON MAINNET ADDRESSES
    address constant DAI_POLYGON = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address constant POOL_ADDRESS_PROVIDER_POLYGON = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address constant REWARDS_CONTROLLER_POLYGON = 0x929EC64c34a17401F460460D4B9390518E5B473e;

    // DEPLOYMENT PARAMETERS - CHANGE THESE FOR YOUR VAULT
    // ===================================================
    address underlyingAsset = DAI_MUMBAI; // An ERC20 address, must have an Aave v3 market
    address aavePoolAddressProvider = POOL_ADDRESS_PROVIDER_MUMBAI;
    address proxyAdmin = address(1);
    address owner = address(2);
    string shareName = "Wrapped aDAI";
    string shareSymbol = "waDAI";
    uint256 fee = 0.1e18; // 10%
    uint256 initialDeposit = 0;
    uint16 referralCode = 4546;
    // ===================================================

    ATokenVault public vault;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("Deploying vault...");

        require(
            initialDeposit != 0,
            "Initial deposit not set. This prevents a frontrunning attack, please set a non-trivial initial deposit."
        );

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the implementation, which disables initializers on construction
        vault = new ATokenVault(underlyingAsset, referralCode, IPoolAddressesProvider(aavePoolAddressProvider));

        // Encode the initializer call
        bytes memory data = abi.encodeWithSelector(ATokenVault.initialize.selector, owner, fee, shareName, shareSymbol, 0);

        // Deploy and initialize the proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(vault), proxyAdmin, data);

        vm.stopBroadcast();

        console.log("Vault impl deployed at: ", address(vault));
        console.log("Vault proxy deployed and initialized at: ", address(proxy));
    }
}
