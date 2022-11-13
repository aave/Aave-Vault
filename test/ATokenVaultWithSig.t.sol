// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {ATokenVaultBaseTest, IATokenVault} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";

import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";

contract ATokenVaultWithSigTest is ATokenVaultBaseTest {
    bytes32 ASSET_DOMAIN_SEPARATOR;

    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aDai;
    MockDAI dai;

    function setUp() public override {
        aDai = new MockAToken();
        pool = new MockAavePool(aDai);
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));

        dai = new MockDAI();

        ASSET_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        vaultAssetAddress = address(aDai);

        vault = new ATokenVault(dai, SHARE_NAME, SHARE_SYMBOL, fee, IPoolAddressesProvider(address(poolAddrProvider)));
    }

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function testDepositWithSig() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        EIP712Signature memory sig = _createPermitSig({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        console.log("balance before", aDai.balanceOf(address(vault)));

        vm.startPrank(ALICE);
        // Not a single approve() in sight
        vault.depositWithSig(amount, ALICE, sig);
        vm.stopPrank();

        console.log("balance after", aDai.balanceOf(address(vault)));
    }

    /*//////////////////////////////////////////////////////////////
                                MINT
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                REDEEM
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                TEST UTILS
    //////////////////////////////////////////////////////////////*/

    function _createPermitSig(
        address owner,
        uint256 ownerPrivKey,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal returns (EIP712Signature memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            ownerPrivKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ASSET_DOMAIN_SEPARATOR,
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline))
                )
            )
        );

        sig = EIP712Signature({v: v, r: r, s: s, deadline: deadline});
    }
}
