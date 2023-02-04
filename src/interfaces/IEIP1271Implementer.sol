// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @title IATokenVaultEvents
 * @author Aave Protocol
 *
 * @notice Defines the interface for calling EIP1271 compliant contracts from the ATokenVault.
 */
interface IEIP1271Implementer {
    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4);
}
