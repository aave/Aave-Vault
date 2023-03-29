// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {IATokenVault} from "../../src/interfaces/IATokenVault.sol";
import "./Constants.sol";

contract PermitSigHelper is Test {
    struct VaultSigParams {
        address assetOwner; // where the shares/assets are flowing from
        uint256 ownerPrivKey; // private key of above address
        uint256 amount; // amount of assets/shares
        address receiver;
        uint256 nonce;
        uint256 deadline;
        bytes32 functionTypehash;
    }

    struct PermitSigParams {
        address owner;
        uint256 ownerPrivKey;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    function createVaultSig(
        bytes32 vaultDomainSeparator,
        VaultSigParams memory params
    ) external returns (IATokenVault.EIP712Signature memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            params.ownerPrivKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    vaultDomainSeparator,
                    keccak256(
                        abi.encode(
                            params.functionTypehash,
                            params.amount,
                            params.receiver,
                            params.assetOwner,
                            params.nonce,
                            params.deadline
                        )
                    )
                )
            )
        );

        sig = IATokenVault.EIP712Signature({v: v, r: r, s: s, deadline: params.deadline});
    }
}
