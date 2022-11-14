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

        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(address(vault)), amount);
    }

    function testDepositWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        EIP712Signature memory sig = _createPermitSig({
            owner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        vm.startPrank(BOB);
        vm.expectRevert(ERR_INVALID_SIGNER);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongPrivKey() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        EIP712Signature memory sig = _createPermitSig({
            owner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        vm.startPrank(BOB);
        vm.expectRevert(ERR_INVALID_SIGNER);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongSpender() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        EIP712Signature memory sig = _createPermitSig({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: BOB,
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        vm.startPrank(BOB);
        vm.expectRevert(ERR_INVALID_SIGNER);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongValue() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        EIP712Signature memory sig = _createPermitSig({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount - 1,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        vm.startPrank(BOB);
        vm.expectRevert(ERR_INVALID_SIGNER);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        EIP712Signature memory sig = _createPermitSig({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE) + 1,
            deadline: block.timestamp
        });

        vm.startPrank(BOB);
        vm.expectRevert(ERR_INVALID_SIGNER);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfPastDeadline() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        uint256 deadline = block.timestamp + 1000;
        skip(1001);
        assertGt(block.timestamp, deadline);

        EIP712Signature memory sig = _createPermitSig({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: deadline
        });

        vm.startPrank(BOB);
        vm.expectRevert(ERR_PERMIT_DEADLINE_EXPIRED);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                MINT
    //////////////////////////////////////////////////////////////*/

    function testMintWithSig() public {
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

        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);

        // Bob calls mint on Alice's behalf
        vm.startPrank(BOB);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(address(vault)), amount);
    }

    function testMintWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        EIP712Signature memory sig = _createPermitSig({
            owner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        vm.startPrank(BOB);
        vm.expectRevert(ERR_INVALID_SIGNER);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongPrivKey() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        EIP712Signature memory sig = _createPermitSig({
            owner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        vm.startPrank(BOB);
        vm.expectRevert(ERR_INVALID_SIGNER);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongSpender() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        EIP712Signature memory sig = _createPermitSig({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: BOB,
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        vm.startPrank(BOB);
        vm.expectRevert(ERR_INVALID_SIGNER);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongValue() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        EIP712Signature memory sig = _createPermitSig({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount - 1,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        vm.startPrank(BOB);
        vm.expectRevert(ERR_INVALID_SIGNER);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        EIP712Signature memory sig = _createPermitSig({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE) + 1,
            deadline: block.timestamp
        });

        vm.startPrank(BOB);
        vm.expectRevert(ERR_INVALID_SIGNER);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfPastDeadline() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        uint256 deadline = block.timestamp + 1000;
        skip(1001);
        assertGt(block.timestamp, deadline);

        EIP712Signature memory sig = _createPermitSig({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: deadline
        });

        vm.startPrank(BOB);
        vm.expectRevert(ERR_PERMIT_DEADLINE_EXPIRED);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

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
