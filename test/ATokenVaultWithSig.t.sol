// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import {IRewardsController} from "aave-periphery/rewards/interfaces/IRewardsController.sol";

import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";

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

bytes32 constant PERMIT_TYPEHASH = keccak256(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
);
bytes32 constant DEPOSIT_WITH_SIG_TYPEHASH = keccak256(
    "DepositWithSig(uint256 assets,address receiver,address depositor,uint256 nonce,uint256 deadline)"
);
bytes32 constant MINT_WITH_SIG_TYPEHASH = keccak256(
    "MintWithSig(uint256 shares,address receiver,address depositor,uint256 nonce,uint256 deadline)"
);
bytes32 constant WITHDRAW_WITH_SIG_TYPEHASH = keccak256(
    "WithdrawWithSig(uint256 assets,address receiver,address owner,uint256 nonce,uint256 deadline)"
);
bytes32 constant REDEEM_WITH_SIG_TYPEHASH = keccak256(
    "RedeemWithSig(uint256 shares,address receiver,address owner,uint256 nonce,uint256 deadline)"
);

contract ATokenVaultWithSigTest is ATokenVaultBaseTest {
    bytes32 VAULT_DOMAIN_SEPARATOR;

    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aDai;
    MockDAI dai;

    function setUp() public override {
        aDai = new MockAToken();
        pool = new MockAavePool(aDai);
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));

        // NOTE: Real DAI has non-standard permit. These tests assume tokens with standard permit
        dai = new MockDAI();

        vaultAssetAddress = address(aDai);

        _deploy(address(dai), address(poolAddrProvider));

        VAULT_DOMAIN_SEPARATOR = vault.DOMAIN_SEPARATOR();
    }

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    // DEPOSIT WITH SIG

    function testDepositWithSig() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, depositSig: sig});
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(address(vault)), amount);
    }

    function testDepositWithSigFailsIfNotApproved() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_TRANSFER_FROM_FAILED);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, depositSig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, depositSig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongPrivateKey() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, depositSig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, depositSig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongValue() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount + 1,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, depositSig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, depositSig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfPastDeadline() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp - 1,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, depositSig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        // Change domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, depositSig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfBadTypehash() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: keccak256(
                "Deposit(uint256 amount,address receiver,address depositor,uint256 nonce,uint256 deadline)"
            )
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, depositSig: sig});
        vm.stopPrank();
    }

    // PERMIT AND DEPOSIT WITH SIG

    function testPermitAndDepositWithSig() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigParams memory permitParams = PermitSigParams({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory permitSig = _createPermitSig(permitParams);
        EIP712Signature memory sig = _createVaultSig(params);

        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vault.permitAndDepositWithSig({
            assets: amount,
            receiver: ALICE,
            depositor: ALICE,
            permitSig: permitSig,
            depositSig: sig
        });
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(address(vault)), amount);
    }

    function testPermitAndDepositWithSigFailsIfPermitFails() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        // Create bad permit sig
        PermitSigParams memory permitParams = PermitSigParams({
            owner: ALICE,
            ownerPrivKey: 1,
            spender: address(vault),
            value: 0,
            nonce: dai.nonces(ALICE),
            deadline: 0
        });

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        // No approve, and bad permit sig
        EIP712Signature memory permitSig = _createPermitSig(permitParams);
        EIP712Signature memory sig = _createVaultSig(params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_PERMIT_DEADLINE_EXPIRED);
        vault.permitAndDepositWithSig({
            assets: amount,
            receiver: ALICE,
            depositor: ALICE,
            permitSig: permitSig,
            depositSig: sig
        });
        vm.stopPrank();
    }

    function testPermitAndDepositWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigParams memory permitParams = PermitSigParams({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        VaultSigParams memory params = VaultSigParams({
            assetOwner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory permitSig = _createPermitSig(permitParams);
        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.permitAndDepositWithSig({
            assets: amount,
            receiver: ALICE,
            depositor: ALICE,
            permitSig: permitSig,
            depositSig: sig
        });
        vm.stopPrank();
    }

    function testPermitAndDepositWithSigFailsIfWrongPrivKey() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigParams memory permitParams = PermitSigParams({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory permitSig = _createPermitSig(permitParams);
        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.permitAndDepositWithSig({
            assets: amount,
            receiver: ALICE,
            depositor: ALICE,
            permitSig: permitSig,
            depositSig: sig
        });
        vm.stopPrank();
    }

    function testPermitAndDepositWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigParams memory permitParams = PermitSigParams({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory permitSig = _createPermitSig(permitParams);
        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.permitAndDepositWithSig({
            assets: amount,
            receiver: ALICE,
            depositor: ALICE,
            permitSig: permitSig,
            depositSig: sig
        });
        vm.stopPrank();
    }

    function testPermitAndDepositWithSigFailsIfWrongValue() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigParams memory permitParams = PermitSigParams({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount + 1,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory permitSig = _createPermitSig(permitParams);
        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.permitAndDepositWithSig({
            assets: amount,
            receiver: ALICE,
            depositor: ALICE,
            permitSig: permitSig,
            depositSig: sig
        });
        vm.stopPrank();
    }

    function testPermitAndDepositWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigParams memory permitParams = PermitSigParams({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory permitSig = _createPermitSig(permitParams);
        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.permitAndDepositWithSig({
            assets: amount,
            receiver: ALICE,
            depositor: ALICE,
            permitSig: permitSig,
            depositSig: sig
        });
        vm.stopPrank();
    }

    function testPermitAndDepositWithSigFailsIfPastDeadline() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        uint256 deadline = block.timestamp + 1000;
        skip(1001);
        assertGt(block.timestamp, deadline);

        PermitSigParams memory permitParams = PermitSigParams({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: deadline,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory permitSig = _createPermitSig(permitParams);
        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.permitAndDepositWithSig({
            assets: amount,
            receiver: ALICE,
            depositor: ALICE,
            permitSig: permitSig,
            depositSig: sig
        });
        vm.stopPrank();
    }

    function testPermitAndDepositWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        // Change domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        PermitSigParams memory permitParams = PermitSigParams({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory permitSig = _createPermitSig(permitParams);
        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.permitAndDepositWithSig({
            assets: amount,
            receiver: ALICE,
            depositor: ALICE,
            permitSig: permitSig,
            depositSig: sig
        });
        vm.stopPrank();
    }

    function testPermitAndDepositWithSigFailsIfBadTypehash() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigParams memory permitParams = PermitSigParams({
            owner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            spender: address(vault),
            value: amount,
            nonce: dai.nonces(ALICE),
            deadline: block.timestamp
        });

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: keccak256(
                "Deposit(uint256 assets,address receiver,address depositor,uint256 nonce,uint256 deadline)"
            ) // Deposit instead of DepositWithSig
        });

        EIP712Signature memory permitSig = _createPermitSig(permitParams);
        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.permitAndDepositWithSig({
            assets: amount,
            receiver: ALICE,
            depositor: ALICE,
            permitSig: permitSig,
            depositSig: sig
        });
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                    MINT
    //////////////////////////////////////////////////////////////*/

    // MINT WITH SIG

    function testMintWithSig() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);

        vm.prank(BOB);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, mintSig: sig});

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(address(vault)), amount);
    }

    function testMintWithSigFailsIfNotApproved() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_TRANSFER_FROM_FAILED);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, mintSig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, mintSig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongPrivateKey() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, mintSig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, mintSig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongValue() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount + 1, receiver: ALICE, depositor: ALICE, mintSig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, mintSig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfPastDeadline() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp - 1,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, mintSig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        // Setting to wrong domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, mintSig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfBadTypehash() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: keccak256(
                "Mint(uint256 shares,address receiver,address depositor,uint256 nonce,uint256 deadline)"
            )
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, mintSig: sig});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testWithdrawWithSig() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        // No approval needed because Alice is reciever
        EIP712Signature memory sig = _createVaultSig(params);

        assertEq(vault.balanceOf(ALICE), amount);
        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), amount);

        vm.startPrank(BOB);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);
    }

    function testWithdrawWithSigToAnotherAccount() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        vm.prank(ALICE);
        vault.approve(BOB, amount);
        EIP712Signature memory sig = _createVaultSig(params);

        assertEq(vault.balanceOf(ALICE), amount);
        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), amount);

        vm.startPrank(OWNER);
        vault.withdrawWithSig({assets: amount, receiver: BOB, owner: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), amount);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);
    }

    function testWithdrawWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfWrongPrivKey() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfWrongAmount() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount + 1,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfWrongDeadline() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp - 1,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        // Change domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfWrongFunctionTypehash() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: keccak256(
                "Withdraw(uint256 assets,address receiver,address owner,uint256 nonce,uint256 deadline)"
            ) // Withdraw not WithdrawWithSig
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                    REDEEM
        //////////////////////////////////////////////////////////////*/

    function testRedeemWithSig() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(vault.balanceOf(ALICE), amount);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), amount);

        vm.startPrank(BOB);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);
    }

    function testRedeemWithSigToAnotherAccount() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        vm.prank(ALICE);
        vault.approve(BOB, amount);
        EIP712Signature memory sig = _createVaultSig(params);

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(vault.balanceOf(ALICE), amount);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), amount);

        vm.startPrank(OWNER);
        vault.redeemWithSig({shares: amount, receiver: BOB, owner: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), amount);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);
    }

    function testRedeemWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: BOB, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfWrongPrivKey() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfWrongAmount() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount + 1,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfWrongDeadline() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp - 1,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        // Setting to wrong domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfWrongFunctionTypehash() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        VaultSigParams memory params = VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        EIP712Signature memory sig = _createVaultSig(params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                TEST UTILS
    //////////////////////////////////////////////////////////////*/

    function _createVaultSig(VaultSigParams memory params) internal returns (EIP712Signature memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            params.ownerPrivKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    VAULT_DOMAIN_SEPARATOR,
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

        sig = EIP712Signature({v: v, r: r, s: s, deadline: params.deadline});
    }

    function _createPermitSig(PermitSigParams memory params) internal returns (EIP712Signature memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            params.ownerPrivKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    dai.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(PERMIT_TYPEHASH, params.owner, params.spender, params.value, params.nonce, params.deadline)
                    )
                )
            )
        );

        sig = EIP712Signature({v: v, r: r, s: s, deadline: params.deadline});
    }

    function _depositFromUser(address user, uint256 amount) public {
        deal(address(dai), user, amount);

        vm.startPrank(user);
        dai.approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();
    }
}
