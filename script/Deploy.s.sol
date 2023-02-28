// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20Upgradeable} from "@openzeppelin-upgradeable/interfaces/IERC20Upgradeable.sol";

import "../src/ATokenVault.sol";

contract Deploy is Script {
    // MUMBAI TESTNET ADDRESSES
    address constant DAI_MUMBAI = 0xF14f9596430931E177469715c591513308244e8F;
    address constant POOL_ADDRESS_PROVIDER_MUMBAI = 0xeb7A892BB04A8f836bDEeBbf60897A7Af1Bf5d7F;
    address constant REWARDS_CONTROLLER_MUMBAI = address(0);

    // POLYGON MAINNET ADDRESSES
    address constant DAI_POLYGON = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address constant POOL_ADDRESS_PROVIDER_POLYGON = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address constant REWARDS_CONTROLLER_POLYGON = 0x929EC64c34a17401F460460D4B9390518E5B473e;

    // DEPLOYMENT PARAMETERS - CHANGE THESE FOR YOUR VAULT
    // ===================================================
    address underlyingAsset = DAI_MUMBAI; // An ERC20 address, must have an Aave v3 market
    address aavePoolAddressProvider = POOL_ADDRESS_PROVIDER_MUMBAI;

    // TODO: Replace with correct addresses
    address proxyAdmin = address(1);
    address owner = address(2);
    string shareName = "Wrapped aDAI";
    string shareSymbol = "waDAI";
    uint256 fee = 0.1e18; // 10%
    uint256 initialDeposit = 10e18;
    uint16 referralCode = 4546;
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
            initialDeposit != 0,
            "Initial deposit not set. This prevents a frontrunning attack, please set a non-trivial initial deposit."
        );

        vm.startBroadcast(deployerPrivateKey);
        // Deploy the implementation, which disables initializers on construction
        vault = new ATokenVault(underlyingAsset, referralCode, IPoolAddressesProvider(aavePoolAddressProvider));
        console.log("Vault impl deployed at: ", address(vault));

        console.log("Deploying proxy...");
        // Encode the initializer call
        bytes memory data = abi.encodeWithSelector(
            ATokenVault.initialize.selector,
            owner,
            fee,
            shareName,
            shareSymbol,
            initialDeposit
        );
        console.logBytes(data);

        address proxyAddr = computeCreateAddress(deployerAddress, vm.getNonce(deployerAddress) + 1);
        IERC20Upgradeable(underlyingAsset).approve(proxyAddr, initialDeposit);
        console.log("Precomputed proxy address: ", proxyAddr);
        console.log("Allowance for proxy: ", IERC20Upgradeable(underlyingAsset).allowance(deployerAddress, proxyAddr));

        // Deploy and initialize the proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(vault), proxyAdmin, data);

        vm.stopBroadcast();

        console.log("Vault proxy deployed and initialized at: ", address(proxy));
    }
}
