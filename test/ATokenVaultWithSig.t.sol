// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";

import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";

import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Errors} from "../src/libraries/Errors.sol";
import {Events} from "../src/libraries/Events.sol";

struct VaultSigParams {
    address assetOwner; // where the shares/assets are flowing from
    uint256 ownerPrivKey; // private key of above address
    uint256 assets;
    address receiver;
    uint256 nonce;
    uint256 deadline;
    bytes32 functionTypehash;
}

contract ATokenVaultWithSigTest is ATokenVaultBaseTest {
    // TODO remove asset separator after permit removed
    bytes32 VAULT_DOMAIN_SEPARATOR;
    bytes32 ASSET_DOMAIN_SEPARATOR;

    bytes32 DEPOSIT_WITH_SIG_TYPEHASH =
        keccak256("DepositWithSig(uint256 assets,address receiver,address depositor,uint256 nonce,uint256 deadline)");

    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aDai;
    MockDAI dai;

    function setUp() public override {
        aDai = new MockAToken();
        pool = new MockAavePool(aDai);
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));

        dai = new MockDAI();

        vaultAssetAddress = address(aDai);

        vault = new ATokenVault(dai, SHARE_NAME, SHARE_SYMBOL, fee, IPoolAddressesProvider(address(poolAddrProvider)));

        VAULT_DOMAIN_SEPARATOR = vault.DOMAIN_SEPARATOR();
        ASSET_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();
        // TODO remove asset separator after permit removed
    }

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function testDepositWithSig() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            assets: amount,
            receiver: ALICE,
            nonce: vault.sigNonces(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        // Alice approves DAI and signs depositWithSig msg
        vm.prank(ALICE);
        dai.approve(address(vault), amount);
        DataTypes.EIP712Signature memory sig = _createVaultSig(params);

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

        VaultSigParams memory params = VaultSigParams({
            assetOwner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            assets: amount,
            receiver: ALICE,
            nonce: vault.sigNonces(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        // Alice approves DAI and signs depositWithSig msg
        vm.prank(ALICE);
        dai.approve(address(vault), amount);
        DataTypes.EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(Errors.SignatureInvalid.selector);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongPrivKey() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            assets: amount,
            receiver: ALICE,
            nonce: vault.sigNonces(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        // Alice approves DAI and signs depositWithSig msg
        vm.prank(ALICE);
        dai.approve(address(vault), amount);
        DataTypes.EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(Errors.SignatureInvalid.selector);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            assets: amount,
            receiver: BOB,
            nonce: vault.sigNonces(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        // Alice approves DAI and signs depositWithSig msg
        vm.prank(ALICE);
        dai.approve(address(vault), amount);
        DataTypes.EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(Errors.SignatureInvalid.selector);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongValue() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            assets: amount + 1,
            receiver: ALICE,
            nonce: vault.sigNonces(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        // Alice approves DAI and signs depositWithSig msg
        vm.prank(ALICE);
        dai.approve(address(vault), amount);
        DataTypes.EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(Errors.SignatureInvalid.selector);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            assets: amount,
            receiver: ALICE,
            nonce: vault.sigNonces(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        // Alice approves DAI and signs depositWithSig msg
        vm.prank(ALICE);
        dai.approve(address(vault), amount);
        DataTypes.EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(Errors.SignatureInvalid.selector);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfPastDeadline() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        uint256 deadline = block.timestamp + 1000;
        skip(1001);
        assertGt(block.timestamp, deadline);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            assets: amount,
            receiver: ALICE,
            nonce: vault.sigNonces(ALICE) + 1,
            deadline: deadline,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        // Alice approves DAI and signs depositWithSig msg
        vm.prank(ALICE);
        dai.approve(address(vault), amount);
        DataTypes.EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(Errors.SignatureExpired.selector);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            assets: amount,
            receiver: ALICE,
            nonce: vault.sigNonces(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        // Change domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        // Alice approves DAI and signs depositWithSig msg
        vm.prank(ALICE);
        dai.approve(address(vault), amount);
        DataTypes.EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(Errors.SignatureInvalid.selector);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfBadTypehash() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            assets: amount,
            receiver: ALICE,
            nonce: vault.sigNonces(ALICE),
            deadline: block.timestamp,
            functionTypehash: keccak256(
                "Deposit(uint256 assets,address receiver,address depositor,uint256 nonce,uint256 deadline)"
            ) // Deposit instead of DepositWithSig
        });

        // Alice approves DAI and signs depositWithSig msg
        vm.prank(ALICE);
        dai.approve(address(vault), amount);
        DataTypes.EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(Errors.SignatureInvalid.selector);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                MINT
    //////////////////////////////////////////////////////////////*/

    function testMintWithSig() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        DataTypes.EIP712Signature memory sig = _createPermitSig({
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

        DataTypes.EIP712Signature memory sig = _createPermitSig({
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

        DataTypes.EIP712Signature memory sig = _createPermitSig({
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

        DataTypes.EIP712Signature memory sig = _createPermitSig({
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

        DataTypes.EIP712Signature memory sig = _createPermitSig({
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

        DataTypes.EIP712Signature memory sig = _createPermitSig({
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

        DataTypes.EIP712Signature memory sig = _createPermitSig({
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

    function testWithdrawWithSig() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        dai.approve(address(vault), amount);
        vault.deposit({assets: amount, receiver: ALICE});
        vm.stopPrank();

        ASSET_DOMAIN_SEPARATOR = vault.DOMAIN_SEPARATOR();
        DataTypes.EIP712Signature memory sig = _createPermitSig({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: BOB,
            value: amount,
            nonce: vault.nonces(ALICE),
            deadline: block.timestamp
        });

        vm.startPrank(BOB);
        console.log(vault.balanceOf(BOB));
        vault.permit(ALICE, BOB, amount, sig.deadline, sig.v, sig.r, sig.s);
        vault.transferFrom({from: ALICE, to: BOB, amount: amount});
        console.log(vault.balanceOf(BOB));
        vm.stopPrank();

        // assertEq(vault.balanceOf(ALICE), amount);
        // assertEq(dai.balanceOf(ALICE), 0);
        // assertEq(dai.balanceOf(BOB), 0);
        // assertEq(dai.balanceOf(address(vault)), 0);
        // assertEq(aDai.balanceOf(address(vault)), amount);

        // // Bob calls withdraw on Alice's behalf
        // vm.startPrank(BOB);
        // vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        // vm.stopPrank();

        // assertEq(vault.balanceOf(ALICE), 0);
        // assertEq(dai.balanceOf(ALICE), amount);
        // assertEq(dai.balanceOf(BOB), 0);
        // assertEq(dai.balanceOf(address(vault)), 0);
        // assertEq(aDai.balanceOf(address(vault)), 0);
    }

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
    ) internal returns (DataTypes.EIP712Signature memory sig) {
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

        sig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: deadline});
    }

    function _createVaultSig(VaultSigParams memory params) internal returns (DataTypes.EIP712Signature memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            params.ownerPrivKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    VAULT_DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            params.functionTypehash,
                            params.assets,
                            params.receiver,
                            params.assetOwner,
                            params.nonce,
                            params.deadline
                        )
                    )
                )
            )
        );

        sig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: params.deadline});
    }
}
