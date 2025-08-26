// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {ATokenVaultFactory} from "../src/ATokenVaultFactory.sol";

/**
 * @title DeployFactoryImplementation
 * @author Aave Labs
 * @notice Script to deploy the aTokenVaultFactory contract implementation
 * @dev Run the script with the following command first:
 * 
 *      forge script script/DeployFactoryImplementation.s.sol:DeployFactoryImplementation -vvvv --rpc-url {$RPC_URL} --account ${ACCOUNT} --slow 
 *  
 * If succeeds, then add the --broadcast flag in order to send the transaction to the network.
 */
contract DeployFactoryImplementation is Script {

    function run() external {

        console.log("BlockNumber: ", block.number);

        console.log("ChainId: ", block.chainid);

        vm.startBroadcast();

        console.log("Deploying aTokenVaultFactory implementation...");

        ATokenVaultFactory factoryImplementation = new ATokenVaultFactory();

        console.log("aTokenVaultFactory implementation deployed at: ", address(factoryImplementation));

        vm.stopBroadcast();
    }
}
