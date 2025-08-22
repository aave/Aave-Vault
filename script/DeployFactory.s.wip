// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {ATokenVaultFactory} from "../src/ATokenVaultFactory.sol";
import {ICreateX} from "@pcaversaccio/createx/ICreateX.sol";
import {ProxyAdmin} from "@openzeppelin/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title DeployFactory
 * @author Aave Labs
 * @notice Script to deploy the aTokenVaultFactory contract with deterministic address even when future versions change
 * @dev Run the script with the following command first:
 * 
 *      forge script script/DeployFactory.s.sol:DeployFactory -vvvv --rpc-url {$RPC_URL} --account ${ACCOUNT} --slow 
 *  
 * If succeeds, then add the --broadcast flag in order to send the transaction to the network.
 */
contract DeployFactory is Script {
    /////////////////// DEPLOYMENT PARAMETERS //////////////////////////
    /**
     * @notice The aTokenVaultFactory's Proxy Admin 
     */
    address constant FACTORY_PROXY_ADMIN = address(0);
    ////////////////////////////////////////////////////////////////////

    address constant EXPECTED_FACTORY_ADDRESS = address(0xa35995bb2fFC5F2b33379C2e95d00C20FbF71E70);

    address constant DEPLOYER_ADDRESS = address(0xFAC70d880Da5923673C502dbC8CeD1675c57e155);

    /**
     * @notice CREATE3 Salt for the deterministic aTokenVaultFactory deployment
     * 
     * @dev Generated through following steps:
     * 
     * Base Salt: keccak256("aave.aTokenVaultFactory")
     *              = 0x36275659667d979dfee1891a4bc3f4c14e3c2bb6a5b996d2f8dec69a6f19c4be
     * 
     *  0x 36275659667d979dfee1891a4bc3f4c14e3c2bb6 a5 b996d2f8dec69a6f19c4be
     * 
     * Add deployer address (0xFAC70d880Da5923673C502dbC8CeD1675c57e155) at the beginning for protection:
     *  0x FAC70d880Da5923673C502dbC8CeD1675c57e155 a5 b996d2f8dec69a6f19c4be
     * 
     * Set the next byte to 0x00 in order to turn off the cross-chain protection:
     *  0x FAC70d880Da5923673C502dbC8CeD1675c57e155 00 b996d2f8dec69a6f19c4be
     * 
     * Keep the final bytes from the base salt
     */
    bytes32 constant FACTORY_SALT = 0xFAC70d880Da5923673C502dbC8CeD1675c57e15500b996d2f8dec69a6f19c4be;

    /**
     * @notice @pcaversaccio/createx's address
     * 
     * @dev Used as CREATE3 factory for deterministic deployments, not depending on the init code.
     */
    address constant CREATEX_ADDRESS = address(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    ICreateX CREATE3_FACTORY = ICreateX(CREATEX_ADDRESS);

    function run() external {

        console.log("Deployer balance: ", address(DEPLOYER_ADDRESS).balance);

        console.log("BlockNumber: ", block.number);

        console.log("ChainId: ", block.chainid);

        require(FACTORY_PROXY_ADMIN != address(0), "FACTORY_PROXY_ADMIN is not set");
        console.log("Factory proxy admin owner: ", FACTORY_PROXY_ADMIN);


        vm.startBroadcast();


        /////// Deploy Renounced ProxyAdmin

        console.log("Deploying vault's renounced proxy admin");

        address renouncedProxyAdmin = address(new ProxyAdmin());

        console.log("Renounced proxy admin deployed at: ", renouncedProxyAdmin);

        ProxyAdmin(renouncedProxyAdmin).renounceOwnership();


        /////// Deploy aTokenVaultFactory Implementation (pass Renounced ProxyAdmin as argument)

        console.log("Deploying aTokenVaultFactory implementation...");

        ATokenVaultFactory factoryImplementation = new ATokenVaultFactory({proxyAdmin: renouncedProxyAdmin});

        console.log("aTokenVaultFactory implementation deployed at: ", address(factoryImplementation));



        /////// Deploy aTokenVaultFactory Proxy

        console.log("Deploying aTokenVaultFactory proxy - Expected at: ", address(EXPECTED_FACTORY_ADDRESS));

        address factoryProxy = CREATE3_FACTORY.deployCreate3({
            salt: FACTORY_SALT,
            initCode: abi.encodePacked(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(factoryImplementation, FACTORY_PROXY_ADMIN, "")
            )
        });

        console.log("aTokenVaultFactory proxy deployed at: ", factoryProxy);

        require(address(factoryProxy) == EXPECTED_FACTORY_ADDRESS, "aTokenVaultFactory Proxy address mismatch");


        vm.stopBroadcast();
    }
}
