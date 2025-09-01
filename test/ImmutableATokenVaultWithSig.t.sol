// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./utils/Constants.sol";
import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";
import {PermitSigHelper} from "./utils/PermitSigHelper.sol";
import {ImmutableATokenVaultBaseTest} from "./ImmutableATokenVaultBaseTest.t.sol";

import {IATokenVault} from "../src/interfaces/IATokenVault.sol";

contract ImmutableATokenVaultWithSigTest is ImmutableATokenVaultBaseTest {
    bytes32 VAULT_DOMAIN_SEPARATOR;

    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aDai;
    MockDAI dai;
    PermitSigHelper permitSigHelper;

    function setUp() public override {
        // NOTE: Real DAI has non-standard permit. These tests assume tokens with standard permit
        dai = new MockDAI();

        aDai = new MockAToken(address(dai));
        pool = new MockAavePool();
        pool.mockReserve(address(dai), aDai);
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));

        vaultAssetAddress = address(aDai);

        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);
        _deploy(address(dai), address(poolAddrProvider));

        VAULT_DOMAIN_SEPARATOR = vault.domainSeparator();
        permitSigHelper = new PermitSigHelper();
    }

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    // DEPOSIT WITH SIG

    function testDepositWithSig() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);
    }

    function testDepositWithSigFailsIfNotApproved() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        // Foundry does not properly decode the bubbled up error from OZ's SafeERC20.
        vm.expectRevert();
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongPrivateKey() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongValue() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount + 1,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfPastDeadline() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp - 1,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        // Change domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositWithSigFailsIfBadTypehash() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
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

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    // DEPOSIT ATOKENS WITH SIG

    function testDepositATokensWithSig() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vault.depositATokensWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);
    }

    function testDepositATokensWithSigFailsIfNotApproved() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        // Foundry does not properly decode the bubbled up error from OZ's SafeERC20.
        vm.expectRevert();
        vault.depositATokensWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositATokensWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositATokensWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositATokensWithSigFailsIfWrongPrivateKey() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositATokensWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositATokensWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositATokensWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositATokensWithSigFailsIfWrongValue() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount + 1,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositATokensWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositATokensWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositATokensWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositATokensWithSigFailsIfPastDeadline() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp - 1,
            functionTypehash: DEPOSIT_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.depositATokensWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositATokensWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        // Change domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositATokensWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testDepositATokensWithSigFailsIfBadTypehash() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: keccak256(
                "DepositATokens(uint256 amount,address receiver,address depositor,uint256 nonce,uint256 deadline)"
            )
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        // Bob calls depositWithSig on Alice's behalf, passing in Alice's sig
        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.depositATokensWithSig({assets: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                    MINT
    //////////////////////////////////////////////////////////////*/

    // MINT WITH SIG

    function testMintWithSig() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.prank(ALICE);
        dai.approve(address(vault), amount);

        vm.prank(BOB);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);
    }

    function testMintWithSigFailsIfNotApproved() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert();
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongPrivateKey() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongValue() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount + 1, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfPastDeadline() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp - 1,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        // Change domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithSigFailsIfBadTypehash() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
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

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    // MINT ATOKENS WITH SIG

    function testMintWithATokensWithSig() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.prank(BOB);
        vault.mintWithATokensWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);
    }

    function testMintWithATokensWithSigFailsIfNotApproved() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert();
        vault.mintWithATokensWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithATokensWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithATokensWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithATokensWithSigFailsIfWrongPrivateKey() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithATokensWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithATokensWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithATokensWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithATokensWithSigFailsIfWrongValue() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithATokensWithSig({shares: amount + 1, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithATokensWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithATokensWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithATokensWithSigFailsIfPastDeadline() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp - 1,
            functionTypehash: MINT_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.mintWithATokensWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithATokensWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        // Change domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: MINT_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithATokensWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testMintWithATokensWithSigFailsIfBadTypehash() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        aDai.approve(address(vault), amount);
        dai.approve(address(pool), amount);
        pool.supply(address(dai), amount, ALICE, 0);
        vm.stopPrank();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: keccak256(
                "MintWithATokens(uint256 shares,address receiver,address depositor,uint256 nonce,uint256 deadline)"
            )
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.mintWithATokensWithSig({shares: amount, receiver: ALICE, depositor: ALICE, sig: sig});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

    // WITHDRAW WITH SIG

    function testWithdrawWithSig() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        // No approval needed because Alice is receiver
        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);

        vm.startPrank(BOB);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
    }

    function testWithdrawWithSigToAnotherAccount() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
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
        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);

        vm.startPrank(OWNER);
        vault.withdrawWithSig({assets: amount, receiver: BOB, owner: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), amount);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
    }

    function testWithdrawWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfWrongPrivKey() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfWrongAmount() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount + 1,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfWrongDeadline() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp - 1,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        // Change domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawWithSigFailsIfWrongFunctionTypehash() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
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

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    // WITHDRAW ATOKENS WITH SIG

    function testWithdrawATokensWithSig() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_ATOKENS_WITH_SIG_TYPEHASH
        });

        // No approval needed because Alice is receiver
        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);

        vm.startPrank(BOB);
        vault.withdrawATokensWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(ALICE), amount);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
    }

    function testWithdrawATokensWithSigToAnotherAccount() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_ATOKENS_WITH_SIG_TYPEHASH
        });

        vm.prank(ALICE);
        vault.approve(BOB, amount);
        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);

        vm.startPrank(OWNER);
        vault.withdrawATokensWithSig({assets: amount, receiver: BOB, owner: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(BOB), amount);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
    }

    function testWithdrawATokensWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: BOB,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawATokensWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawATokensWithSigFailsIfWrongPrivKey() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawATokensWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawATokensWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawATokensWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawATokensWithSigFailsIfWrongAmount() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount + 1,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawATokensWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawATokensWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawATokensWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawATokensWithSigFailsIfWrongDeadline() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp - 1,
            functionTypehash: WITHDRAW_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.withdrawATokensWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawATokensWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        // Change domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: WITHDRAW_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawATokensWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testWithdrawATokensWithSigFailsIfWrongFunctionTypehash() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: keccak256(
                "WithdrawATokens(uint256 assets,address receiver,address owner,uint256 nonce,uint256 deadline)"
            )
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.withdrawATokensWithSig({assets: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                    REDEEM
    //////////////////////////////////////////////////////////////*/

    // REDEEM WITH SIG

    function testRedeemWithSig() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);

        vm.startPrank(BOB);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), 0);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
    }

    function testRedeemWithSigToAnotherAccount() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        vm.prank(ALICE);
        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);

        vm.startPrank(OWNER);
        vault.redeemWithSig({shares: amount, receiver: BOB, owner: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(BOB), amount);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
    }

    function testRedeemWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: BOB, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfWrongPrivKey() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfWrongAmount() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount + 1,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfWrongDeadline() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp - 1,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        // Change domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithSigFailsIfWrongFunctionTypehash() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    // REDEEM AS ATOKENS WITH SIG

    function testRedeemWithATokensWithSig() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);

        vm.startPrank(BOB);
        vault.redeemWithATokensWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(ALICE), amount);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
    }

    function testRedeemWithATokensWithSigToAnotherAccount() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        vm.prank(ALICE);
        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);

        vm.startPrank(OWNER);
        vault.redeemWithATokensWithSig({shares: amount, receiver: BOB, owner: ALICE, sig: sig});
        vm.stopPrank();

        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(BOB), amount);
        assertEq(vault.balanceOf(BOB), 0);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
    }

    function testRedeemWithATokensWithSigFailsIfWrongOwner() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithATokensWithSig({shares: amount, receiver: ALICE, owner: BOB, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithATokensWithSigFailsIfWrongPrivKey() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: BOB_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithATokensWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithATokensWithSigFailsIfWrongReceiver() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: BOB,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithATokensWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithATokensWithSigFailsIfWrongAmount() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount + 1,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithATokensWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithATokensWithSigFailsIfWrongNonce() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE) + 1,
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithATokensWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithATokensWithSigFailsIfWrongDeadline() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp - 1,
            functionTypehash: REDEEM_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_EXPIRED);
        vault.redeemWithATokensWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithATokensWithSigFailsIfBadDomainSeparator() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        // Change domain separator
        VAULT_DOMAIN_SEPARATOR = dai.DOMAIN_SEPARATOR();

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: REDEEM_WITH_ATOKENS_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithATokensWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    function testRedeemWithATokensWithSigFailsIfWrongFunctionTypehash() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        PermitSigHelper.VaultSigParams memory params = PermitSigHelper.VaultSigParams({
            assetOwner: ALICE,
            ownerPrivKey: ALICE_PRIV_KEY,
            amount: amount,
            receiver: ALICE,
            nonce: vault.getSigNonce(ALICE),
            deadline: block.timestamp,
            functionTypehash: DEPOSIT_WITH_SIG_TYPEHASH
        });

        IATokenVault.EIP712Signature memory sig = permitSigHelper.createVaultSig(VAULT_DOMAIN_SEPARATOR, params);

        vm.startPrank(BOB);
        vm.expectRevert(ERR_SIG_INVALID);
        vault.redeemWithATokensWithSig({shares: amount, receiver: ALICE, owner: ALICE, sig: sig});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                TEST UTILS
    //////////////////////////////////////////////////////////////*/

    function _depositFromUser(address user, uint256 amount) public {
        deal(address(dai), user, amount);

        vm.startPrank(user);
        dai.approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();
    }
}
