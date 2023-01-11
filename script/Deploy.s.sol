// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Script.sol";
import "../src/ATokenVault.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import {IRewardsController} from "aave-periphery/rewards/interfaces/IRewardsController.sol";

contract Deploy is Script {
    // MUMBAI TESTNET ADDRESSES
    address constant DAI_MUMBAI = 0x9A753f0F7886C9fbF63cF59D0D4423C5eFaCE95B;
    address constant POOL_ADDRESS_PROVIDER_MUMBAI = 0x5343b5bA672Ae99d627A1C87866b8E53F47Db2E6;
    address constant REWARDS_CONTROLLER_MUMBAI = address(0);

    // DEPLOYMENT PARAMETERS - CHANGE THESE FOR YOUR VAULT
    // ===================================================
    address underlyingAsset = DAI_MUMBAI; // An ERC20 address, must have an Aave v3 market
    address aavePoolAddressProvider = POOL_ADDRESS_PROVIDER_MUMBAI;
    address aaveRewardsController = REWARDS_CONTROLLER_MUMBAI;
    string vaultShareName = "Wrapped aDAI";
    string vaultShareSymbol = "waDAI";
    uint256 fee = 0.1e18; // 10%
    // ===================================================

    ATokenVault public vault;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        vault = new ATokenVault(
            ERC20(underlyingAsset),
            vaultShareName,
            vaultShareSymbol,
            fee,
            IPoolAddressesProvider(aavePoolAddressProvider),
            IRewardsController(aaveRewardsController)
        );

        vm.stopBroadcast();

        console.log("Vault deployed at: ", address(vault));
    }
}
