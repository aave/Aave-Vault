// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {ATokenVaultFactory} from "../src/ATokenVaultFactory.sol";

contract DeployFactory is Script {
    // DEPLOYMENT PARAMETERS - CHANGE THESE FOR YOUR FACTORY
    // ===================================================
    address constant PROXY_ADMIN_ADDRESS = address(0); // Address of the factory proxy admin
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
        console.log("Proxy admin for deployed vaults: ", PROXY_ADMIN_ADDRESS);
        console.log("Deploying vault factory...");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the implementation, which disables initializers on construction
        ATokenVaultFactory factory = new ATokenVaultFactory({proxyAdmin: PROXY_ADMIN_ADDRESS});
        console.log("Factory deployed at: ", address(factory));

        vm.stopBroadcast();
    }
}
