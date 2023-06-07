// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./utils/Constants.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {MathUpgradeable} from "@openzeppelin-upgradeable/utils/math/MathUpgradeable.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {ATokenVaultForkBaseTest} from "./ATokenVaultForkBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";

contract ATokenVaultForkTest is ATokenVaultForkBaseTest {
    using MathUpgradeable for uint256;

    /*//////////////////////////////////////////////////////////////
                        POLYGON FORK TESTS
    //////////////////////////////////////////////////////////////*/

    function testForkWorks() public {
        assertEq(vm.activeFork(), polygonFork);
    }

    function testForkAtExpectedBlock() public {
        assertEq(block.number, POLYGON_FORK_BLOCK);
    }

    /*//////////////////////////////////////////////////////////////
                                NEGATIVES
    //////////////////////////////////////////////////////////////*/

    function testDeployRevertsWithUnlistedAsset() public {
        // UNI token is not listed on Aave v3
        address uniToken = 0xb33EaAd8d922B1083446DC23f610c2567fB5180f;

        vm.expectRevert(ERR_ASSET_NOT_SUPPORTED);
        vault = new ATokenVault(uniToken, referralCode, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));
    }

    function testDeployRevertsWithBadPoolAddressProvider() public {
        vm.expectRevert();
        vault = new ATokenVault(address(dai), referralCode, IPoolAddressesProvider(address(0)));
    }

    function testCannotInitImpl() public {
        vault = new ATokenVault(address(dai), referralCode, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));
        vm.expectRevert(ERR_INITIALIZED);
        vault.initialize(OWNER, fee, SHARE_NAME, SHARE_SYMBOL, 0);
    }

    function testCannotInitProxyTwice() public {
        vm.expectRevert(ERR_INITIALIZED);
        vault.initialize(OWNER, fee, SHARE_NAME, SHARE_SYMBOL, 1);
    }

    function testInitZeroOwner() public {
        vault = new ATokenVault(address(dai), referralCode, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));

        bytes memory data = abi.encodeWithSelector(ATokenVault.initialize.selector, address(0), 0, SHARE_NAME, SHARE_SYMBOL, 1);

        vm.expectRevert(ERR_ZERO_ADDRESS_NOT_VALID);
        new TransparentUpgradeableProxy(address(vault), PROXY_ADMIN, data);
    }

    function testInitZeroInitialDeposit() public {
        vault = new ATokenVault(address(dai), referralCode, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));

        bytes memory data = abi.encodeWithSelector(ATokenVault.initialize.selector, OWNER, 0, SHARE_NAME, SHARE_SYMBOL, 0);

        vm.expectRevert(ERR_ZERO_INITIAL_DEPOSIT);
        new TransparentUpgradeableProxy(address(vault), PROXY_ADMIN, data);
    }

    function testInitProxyRevertsFeeTooHigh() public {
        vault = new ATokenVault(address(dai), referralCode, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));

        bytes memory data = abi.encodeWithSelector(
            ATokenVault.initialize.selector,
            OWNER,
            SCALE + 1,
            SHARE_NAME,
            SHARE_SYMBOL,
            1
        );

        vm.expectRevert(ERR_FEE_TOO_HIGH);
        new TransparentUpgradeableProxy(address(vault), PROXY_ADMIN, data);
    }

    function testNonOwnerCannotWithdrawFees() public {
        uint256 feesAmount = 50 * ONE;
        _deployAndCheckProps();
        _accrueFeesInVault(feesAmount);

        uint256 feesAccrued = vault.getClaimableFees();
        assertGt(feesAccrued, feesAmount); // must have accrued some fees

        vm.startPrank(ALICE);
        vm.expectRevert(ERR_NOT_OWNER);
        vault.withdrawFees(ALICE, feesAccrued);
        vm.stopPrank();
    }

    function testNonOwnerCannotSetFee() public {
        _deployAndCheckProps();

        vm.startPrank(ALICE);
        vm.expectRevert(ERR_NOT_OWNER);
        vault.setFee(0);
        vm.stopPrank();
    }

    function testOwnerCannotSetFeeHigherThanScale() public {
        _deployAndCheckProps();

        vm.startPrank(OWNER);
        vm.expectRevert(ERR_FEE_TOO_HIGH);
        vault.setFee(SCALE + 1);
        vm.stopPrank();
    }

    function testOwnerCannotWithdrawMoreFeesThenEarned() public {
        uint256 feesAmount = 50 * ONE;
        _deployAndCheckProps();

        // First accrue ~50 DAI in fees
        _accrueFeesInVault(feesAmount);

        // Then deposit ~50 more DAI of user funds (should not be able to withdraw as owner)
        deal(address(dai), ALICE, feesAmount);
        vm.startPrank(ALICE);
        dai.approve(address(vault), feesAmount);
        vault.deposit(feesAmount, ALICE);
        skip(1);
        vm.stopPrank();

        uint256 feesAccrued = vault.getClaimableFees();
        uint256 vaultADaiBalance = aDai.balanceOf(address(vault));

        assertGe(feesAccrued, feesAmount); //Actual fees earned >= feesAmount
        assertGt(vaultADaiBalance, feesAccrued); //Actual vault balance > feesAmount

        vm.startPrank(OWNER);
        vm.expectRevert(ERR_INSUFFICIENT_FEES);
        vault.withdrawFees(OWNER, feesAccrued + ONE); // Try to withdraw more than accrued
        vm.stopPrank();
    }

    function testNonOwnerCannotRescueTokens() public {
        _deployAndCheckProps();

        vm.startPrank(ALICE);
        vm.expectRevert(ERR_NOT_OWNER);
        vault.emergencyRescue(address(dai), ALICE, ONE);
        vm.stopPrank();
    }

    function testCannotRescueAToken() public {
        _deployAndCheckProps();

        vm.startPrank(OWNER);
        vm.expectRevert(ERR_CANNOT_RESCUE_ATOKEN);
        vault.emergencyRescue(address(aDai), OWNER, ONE);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                POSITIVES
    //////////////////////////////////////////////////////////////*/

    function testInitProxyWithInitialDeposit() public {
        uint256 amount = 1e18;

        vault = new ATokenVault(address(dai), referralCode, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));

        bytes memory data = abi.encodeWithSelector(
            ATokenVault.initialize.selector,
            OWNER,
            fee,
            SHARE_NAME,
            SHARE_SYMBOL,
            amount
        );
        address proxyAddr = computeCreateAddress(address(this), vm.getNonce(address(this)));

        deal(address(dai), address(this), amount);
        dai.approve(address(proxyAddr), amount);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(vault), PROXY_ADMIN, data);

        vault = ATokenVault(address(proxy));

        assertEq(vault.totalSupply(), amount);
        assertEq(vault.balanceOf(address(vault)), amount);
        assertEq(vault.convertToShares(amount), amount);
    }

    function testDeploySucceedsWithValidParams() public {
        _deployAndCheckProps();
    }

    function testDeployEmitsFeeEvent() public {
        uint256 initialLockDeposit = 10e18;

        vault = new ATokenVault(address(dai), referralCode, vault.POOL_ADDRESSES_PROVIDER());

        bytes memory data = abi.encodeWithSelector(
            ATokenVault.initialize.selector,
            OWNER,
            fee,
            SHARE_NAME,
            SHARE_SYMBOL,
            initialLockDeposit
        );
        address proxyAddr = computeCreateAddress(address(this), vm.getNonce(address(this)));

        deal(address(dai), address(this), initialLockDeposit);
        dai.approve(address(proxyAddr), initialLockDeposit);

        // no indexed fields, just data check (4th param)
        vm.expectEmit(true, true, false, true);
        emit FeeUpdated(0, fee);
        new TransparentUpgradeableProxy(address(vault), PROXY_ADMIN, data);
    }

    function testOwnerCanWithdrawFees() public {
        uint256 feesAmount = 50 * ONE;
        _deployAndCheckProps();
        _accrueFeesInVault(feesAmount);

        uint256 feesAccrued = vault.getClaimableFees();

        assertGt(feesAccrued, feesAmount); // must have accrued some fees

        vm.startPrank(OWNER);
        vault.withdrawFees(OWNER, feesAccrued);
        vm.stopPrank();

        assertEq(aDai.balanceOf(OWNER), feesAccrued);
        assertEq(vault.getClaimableFees(), 0);
    }

    function testWithdrawFeesEmitsEvent() public {
        uint256 feesAmount = 50 * ONE;
        _deployAndCheckProps();
        _accrueFeesInVault(feesAmount);

        uint256 feesAccrued = vault.getClaimableFees();
        uint256 vaultADaiBalanceBefore = aDai.balanceOf(address(vault));

        assertGt(feesAccrued, feesAmount);

        vm.startPrank(OWNER);
        vm.expectEmit(true, true, false, true, address(vault));
        emit FeesWithdrawn(OWNER, feesAccrued, vaultADaiBalanceBefore - feesAccrued, 0);
        vault.withdrawFees(OWNER, feesAccrued);
        vm.stopPrank();
    }

    function testOwnerCanSetFee() public {
        _deployAndCheckProps();

        uint256 newFee = 0.1e18; //10%
        assertFalse(newFee == vault.getFee()); // new fee must be different

        vm.startPrank(OWNER);
        vault.setFee(newFee);
        vm.stopPrank();

        assertEq(vault.getFee(), newFee);
    }

    function testSetFeeEmitsEvent() public {
        _deployAndCheckProps();

        uint256 newFee = 0.1e18; //10%
        assertFalse(newFee == vault.getFee()); // new fee must be different

        vm.startPrank(OWNER);
        vm.expectEmit(true, true, false, true, address(vault));
        emit FeeUpdated(vault.getFee(), newFee);
        vault.setFee(newFee);
        vm.stopPrank();
    }

    function testOwnerCanRescueTokens() public {
        _deployAndCheckProps();

        deal(address(dai), address(vault), ONE);

        assertEq(dai.balanceOf(address(vault)), ONE);
        assertEq(dai.balanceOf(OWNER), 0);

        vm.startPrank(OWNER);
        vault.emergencyRescue(address(dai), OWNER, ONE);
        vm.stopPrank();

        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(dai.balanceOf(OWNER), ONE);
    }

    function testEmergencyRescueEmitsEvent() public {
        _deployAndCheckProps();

        deal(address(dai), address(vault), ONE);

        vm.startPrank(OWNER);
        vm.expectEmit(true, true, false, true, address(vault));
        emit EmergencyRescue(address(dai), OWNER, ONE);
        vault.emergencyRescue(address(dai), OWNER, ONE);
        vm.stopPrank();
    }

    function testTotalAssetsReturnsInitialDepositWhenEmpty() public {
        _deployAndCheckProps();
        assertEq(vault.totalAssets(), initialLockDeposit);
    }

    function testTotalAssetsPositiveNoFeesAccrued() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();
        _depositFromUser(ALICE, amount);
        assertEq(vault.totalAssets(), amount + initialLockDeposit);
    }

    function testTotalAssetsPositiveNetSomeFeesAccrued() public {
        uint256 amount = HUNDRED;
        uint256 feesAmount = 50 * ONE;
        _deployAndCheckProps();

        _accrueFeesInVault(feesAmount);
        _depositFromUser(ALICE, amount);

        uint256 vaultAssetBalance = aDai.balanceOf(address(vault));

        assertApproxEqRel(vault.totalAssets(), vaultAssetBalance - feesAmount, ONE_BPS);
    }

    function testTotalAssetsDepositThenWithdrawWithFeesRemaining() public {
        uint256 amount = HUNDRED;
        uint256 feesAmount = 50 * ONE;
        _deployAndCheckProps();

        _accrueFeesInVault(feesAmount);
        _depositFromUser(ALICE, amount);

        uint256 vaultAssetBalance = aDai.balanceOf(address(vault));

        assertApproxEqRel(vault.totalAssets(), vaultAssetBalance - feesAmount, ONE_BPS);

        _withdrawFromUser(ALICE, 0);

        uint256 initialLockDepositValue = vault.convertToAssets(initialLockDeposit);

        assertEq(vault.totalAssets(), initialLockDepositValue, "Total assets not equal to initial lock deposit less fees"); // No user funds bar the intiial deposit left in vault, only fees
        assertEq(
            vault.getClaimableFees(),
            aDai.balanceOf(address(vault)) - initialLockDepositValue,
            "Fees not same as aDAI balance less initial lock deposit"
        );
        assertGt(initialLockDepositValue, 0, "Initial lock deposit value not greater than zero");
        assertGt(vault.getClaimableFees(), 0, "Fees not greater than zero"); // Fees remain
    }

    function testAccrueYieldUpdatesOnTimestampDiff() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();
        skip(10);

        uint256 lastVaultBalance = vault.getLastVaultBalance();

        deal(address(dai), ALICE, amount * 2);
        vm.prank(ALICE);
        dai.approve(address(vault), amount * 2);

        vm.record();

        vm.prank(ALICE);
        vault.deposit(amount, ALICE);
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(vault));

        _accrueYieldInVault(100); // simulate some yield

        skip(1);

        vm.prank(ALICE);
        vault.deposit(amount, ALICE);
        (bytes32[] memory reads2, bytes32[] memory writes2) = vm.accesses(address(vault));

        assertEq(reads2.length, reads.length, "unexpected number of reads"); // same number of reads
        assertEq(writes2.length, writes.length, "unexpected number of writes"); // same number of writes

        assertApproxEqRel(vault.getLastVaultBalance(), lastVaultBalance + (2 * amount), ONE_BPS);
    }

    function testAccrueYieldUpdatesOnSameTimestamp() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();
        skip(10);

        uint256 prevTimestamp = block.timestamp;

        uint256 lastVaultBalance = vault.getLastVaultBalance();

        deal(address(dai), ALICE, amount * 2);
        vm.prank(ALICE);
        dai.approve(address(vault), amount * 2);

        vm.record();

        vm.prank(ALICE);
        vault.deposit(amount, ALICE);
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(vault));

        _accrueYieldInVault(100); // simulate some yield

        vm.prank(ALICE);
        vault.deposit(amount, ALICE);
        (bytes32[] memory reads2, bytes32[] memory writes2) = vm.accesses(address(vault));

        assertEq(reads2.length, reads.length, "unexpected number of reads"); // same number of reads
        assertEq(writes2.length, writes.length, "unexpected number of writes"); // same number of writes

        assertEq(block.timestamp, prevTimestamp);

        assertApproxEqRel(vault.getLastVaultBalance(), lastVaultBalance + (2 * amount), ONE_BPS);
    }

    function testAccrueYieldEmitsEvent() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();

        _depositFromUser(ALICE, amount);

        uint256 vaultBalanceBefore = aDai.balanceOf(address(vault));

        skip(365 days);

        uint256 vaultBalanceAfter = aDai.balanceOf(address(vault));

        uint256 expectedNewYield = vaultBalanceAfter - vaultBalanceBefore;
        uint256 expectedFeesFromYield = (expectedNewYield * vault.getFee()) / SCALE;

        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        dai.approve(address(vault), amount);

        vm.expectEmit(false, false, false, true, address(vault));
        emit YieldAccrued(expectedNewYield, expectedFeesFromYield, vaultBalanceAfter);
        vault.deposit(amount, ALICE);
        vm.stopPrank();
    }

    function testAccrueYieldNoEmitsEvent() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();

        _depositFromUser(ALICE, amount);
        uint256 vaultBalanceBefore = aDai.balanceOf(address(vault));

        skip(365 days);

        uint256 vaultBalanceAfter = aDai.balanceOf(address(vault));
        uint256 expectedNewYield = vaultBalanceAfter - vaultBalanceBefore;
        uint256 expectedFeesFromYield = (expectedNewYield * vault.getFee()) / SCALE;

        deal(address(dai), ALICE, amount * 2);
        vm.startPrank(ALICE);
        dai.approve(address(vault), amount * 2);

        vm.record();

        // Event emission
        vm.expectEmit(false, false, false, true, address(vault));
        emit YieldAccrued(expectedNewYield, expectedFeesFromYield, vaultBalanceAfter);
        vault.deposit(amount, ALICE);
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(vault));

        // No event emission
        vault.deposit(amount, ALICE);
        (bytes32[] memory reads2, bytes32[] memory writes2) = vm.accesses(address(vault));

        assertEq(reads2.length, reads.length - 7, "wrong reads"); // 3 in getClaimableFees, 4 in _accrueYield
        assertEq(writes2.length, writes.length - 2, "wrong writes"); // 2 in _accrueYield

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT AND MINT
    //////////////////////////////////////////////////////////////*/

    function testDepositFailsWithZeroAssets() public {
        vm.prank(ALICE);
        vm.expectRevert(ERR_ZERO_SHARES);
        vault.deposit(0, ALICE);
    }

    function testDepositFailsWithExceedsMax() public {
        // mock call to Aave Pool
        MockAavePool mp = new MockAavePool(new MockAToken(address(dai)));
        mp.setReserveConfigMap(RESERVE_CONFIG_MAP_INACTIVE);
        vm.mockCall(
            address(vault.AAVE_POOL()),
            abi.encodeWithSelector(IPool.getReserveData.selector, address(dai)),
            abi.encode(mp.getReserveData(address(dai)))
        );
        vm.prank(ALICE);
        vm.expectRevert(ERR_DEPOSIT_EXCEEDS_MAX);
        vault.deposit(ONE, ALICE);
    }

    function testDepositSuppliesAave() public {
        _deployAndCheckProps();

        deal(address(dai), ALICE, ONE);

        assertEq(dai.balanceOf(ALICE), ONE);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
        assertEq(vault.balanceOf(ALICE), 0);

        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vm.expectEmit(true, true, false, true, address(vault));
        emit Deposit(ALICE, ALICE, ONE, ONE);
        vault.deposit(ONE, ALICE);
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), ONE + initialLockDeposit);
        assertEq(vault.balanceOf(ALICE), ONE);
    }

    function testDepositATokens() public {
        vm.startPrank(ALICE);
        deal(address(dai), ALICE, ONE);

        dai.approve(POLYGON_AAVE_POOL, ONE);
        IPool(POLYGON_AAVE_POOL).supply(address(dai), ONE, ALICE, 0);

        assertEq(aDai.balanceOf(ALICE), ONE);

        aDai.approve(address(vault), ONE);
        vm.expectEmit(true, true, false, true, address(vault));
        emit Deposit(ALICE, ALICE, ONE, ONE);
        vault.depositATokens(ONE, ALICE);

        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), ONE + initialLockDeposit);
        assertEq(vault.balanceOf(ALICE), ONE);
    }

    function testDepositATokensWithExceedsMax() public {
        // mock call to Aave Pool
        MockAavePool mp = new MockAavePool(new MockAToken(address(dai)));
        mp.setReserveConfigMap(RESERVE_CONFIG_MAP_INACTIVE);
        vm.mockCall(
            address(vault.AAVE_POOL()),
            abi.encodeWithSelector(IPool.getReserveData.selector, address(dai)),
            abi.encode(mp.getReserveData(address(dai)))
        );

        vm.startPrank(ALICE);
        deal(address(dai), ALICE, ONE);

        dai.approve(POLYGON_AAVE_POOL, ONE);
        IPool(POLYGON_AAVE_POOL).supply(address(dai), ONE, ALICE, 0);

        assertEq(aDai.balanceOf(ALICE), ONE);

        aDai.approve(address(vault), ONE);
        vm.expectEmit(true, true, false, true, address(vault));
        emit Deposit(ALICE, ALICE, ONE, ONE);
        vault.depositATokens(ONE, ALICE);

        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), ONE + initialLockDeposit);
        assertEq(vault.balanceOf(ALICE), ONE);
    }

    function testDepositAffectedByExchangeRate() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount - initialLockDeposit);

        // still 1:1 exchange rate
        assertEq(vault.convertToShares(amount), amount);
        assertEq(vault.balanceOf(ALICE), amount - initialLockDeposit);

        // Increase share/asset exchange rate
        uint256 fee = vault.getFee();
        uint256 amountPlusFee = amount.mulDiv(SCALE, SCALE - fee, MathUpgradeable.Rounding.Up);
        _accrueYieldInVault(amountPlusFee);

        // Now 2:1 assets to shares exchange rate
        assertEq(vault.convertToShares(amount), amount / 2);

        vm.startPrank(ALICE);
        deal(address(dai), ALICE, amount);
        dai.approve(address(vault), amount);
        vm.expectEmit(true, true, false, true, address(vault));
        emit Deposit(ALICE, ALICE, amount, amount / 2);
        vault.deposit(amount, ALICE);
        vm.stopPrank();

        assertEq(vault.balanceOf(ALICE), amount + (amount / 2) - initialLockDeposit);
    }

    function testMintFailsWithExceedsMax() public {
        // mock call to Aave Pool
        MockAavePool mp = new MockAavePool(new MockAToken(address(dai)));
        mp.setReserveConfigMap(RESERVE_CONFIG_MAP_INACTIVE);
        vm.mockCall(
            address(vault.AAVE_POOL()),
            abi.encodeWithSelector(IPool.getReserveData.selector, address(dai)),
            abi.encode(mp.getReserveData(address(dai)))
        );
        vm.prank(ALICE);
        vm.expectRevert(ERR_MINT_EXCEEDS_MAX);
        vault.mint(ONE, ALICE);
    }

    function testMintSuppliesAave() public {
        _deployAndCheckProps();

        deal(address(dai), ALICE, ONE);

        assertEq(dai.balanceOf(ALICE), ONE);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
        assertEq(vault.balanceOf(ALICE), 0);

        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vm.expectEmit(true, true, false, true, address(vault));
        emit Deposit(ALICE, ALICE, ONE, ONE);
        vault.mint(ONE, ALICE);
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), ONE + initialLockDeposit);
        assertEq(vault.balanceOf(ALICE), ONE);
    }

    function testMintATokensWithExceedsMax() public {
        // mock call to Aave Pool
        MockAavePool mp = new MockAavePool(new MockAToken(address(dai)));
        mp.setReserveConfigMap(RESERVE_CONFIG_MAP_INACTIVE);
        vm.mockCall(
            address(vault.AAVE_POOL()),
            abi.encodeWithSelector(IPool.getReserveData.selector, address(dai)),
            abi.encode(mp.getReserveData(address(dai)))
        );

        vm.startPrank(ALICE);
        deal(address(dai), ALICE, ONE);

        dai.approve(POLYGON_AAVE_POOL, ONE);
        IPool(POLYGON_AAVE_POOL).supply(address(dai), ONE, ALICE, 0);

        assertEq(aDai.balanceOf(ALICE), ONE);

        aDai.approve(address(vault), ONE);
        vm.expectEmit(true, true, false, true, address(vault));
        emit Deposit(ALICE, ALICE, ONE, ONE);
        vault.mintWithATokens(ONE, ALICE);

        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), ONE + initialLockDeposit);
        assertEq(vault.balanceOf(ALICE), ONE);
    }

    function testMintATokens() public {
        vm.startPrank(ALICE);
        deal(address(dai), ALICE, ONE);

        dai.approve(POLYGON_AAVE_POOL, ONE);
        IPool(POLYGON_AAVE_POOL).supply(address(dai), ONE, ALICE, 0);

        assertEq(aDai.balanceOf(ALICE), ONE);

        aDai.approve(address(vault), ONE);
        vm.expectEmit(true, true, false, true, address(vault));
        emit Deposit(ALICE, ALICE, ONE, ONE);
        vault.mintWithATokens(ONE, ALICE);

        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), ONE + initialLockDeposit);
        assertEq(vault.balanceOf(ALICE), ONE);
    }

    function testMintAffectedByExchangeRate() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount - initialLockDeposit);

        // still 1:1 exchange rate
        assertEq(vault.convertToShares(amount), amount);
        assertEq(vault.balanceOf(ALICE), amount - initialLockDeposit);

        // Increase share/asset exchange rate
        uint256 fee = vault.getFee();
        uint256 amountPlusFee = amount.mulDiv(SCALE, SCALE - fee, MathUpgradeable.Rounding.Up);
        _accrueYieldInVault(amountPlusFee);

        // Now 2:1 assets to shares exchange rate
        assertEq(vault.convertToShares(amount), amount / 2);

        vm.startPrank(ALICE);
        deal(address(dai), ALICE, amount);
        dai.approve(address(vault), amount);
        vm.expectEmit(true, true, false, true, address(vault));
        emit Deposit(ALICE, ALICE, amount, amount / 2);
        vault.mint(amount / 2, ALICE);
        vm.stopPrank();

        assertEq(vault.balanceOf(ALICE), HUNDRED + (HUNDRED / 2) - initialLockDeposit);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW AND REDEEM
    //////////////////////////////////////////////////////////////*/

    function testWithdrawFailsWithExceedsMax() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();

        _depositFromUser(ALICE, amount);

        vm.prank(ALICE);
        uint256 maxWithdraw = vault.maxWithdraw(ALICE);
        vm.expectRevert(ERR_WITHDRAW_EXCEEDS_MAX);
        vault.withdraw(maxWithdraw + 1, ALICE, ALICE);
    }

    function testWithdrawBasic() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();

        _depositFromUser(ALICE, amount);

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);

        vm.startPrank(ALICE);
        vm.expectEmit(true, true, true, true, address(vault));
        emit Withdraw(ALICE, ALICE, ALICE, amount, amount);
        vault.withdraw(amount, ALICE, ALICE);
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
    }

    function testWithdrawATokens() public {
        _depositFromUser(ALICE, ONE);

        vm.startPrank(ALICE);
        vm.expectEmit(true, true, true, true, address(vault));
        emit Withdraw(ALICE, ALICE, ALICE, ONE, ONE);
        vault.withdrawATokens(ONE, ALICE, ALICE);

        assertEq(aDai.balanceOf(ALICE), ONE);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
        assertEq(vault.balanceOf(ALICE), 0);
    }

    function testWithdrawAfterYieldEarned() public {
        uint256 amount = HUNDRED;
        uint256 adjustedAmount = amount - initialLockDeposit;
        uint256 expectedAliceAmountEnd = adjustedAmount + adjustedAmount;

        _depositFromUser(ALICE, adjustedAmount);

        // still 1:1 exchange rate
        assertEq(vault.convertToShares(amount), amount);
        assertEq(vault.balanceOf(ALICE), adjustedAmount);

        // Increase share/asset exchange rate
        uint256 fee = vault.getFee();
        uint256 amountPlusFee = amount.mulDiv(SCALE, SCALE - fee, MathUpgradeable.Rounding.Up);
        uint256 feesTaken = amountPlusFee - amount;
        _accrueYieldInVault(amountPlusFee);

        // Now 2:1 assets to shares exchange rate
        assertEq(vault.convertToAssets(amount), amount * 2);

        skip(1);

        uint256 aliceMaxWithdrawable = vault.maxWithdraw(ALICE);

        assertApproxEqRel(aliceMaxWithdrawable, expectedAliceAmountEnd, ONE_BPS);

        vm.startPrank(ALICE);
        vm.expectEmit(true, true, true, true, address(vault));
        emit Withdraw(ALICE, ALICE, ALICE, aliceMaxWithdrawable, adjustedAmount);
        vault.withdraw(aliceMaxWithdrawable, ALICE, ALICE);
        vm.stopPrank();

        assertEq(
            aDai.balanceOf(address(vault)) - vault.convertToAssets(initialLockDeposit),
            vault.getClaimableFees(),
            "FEES NOT SAME AS VAULT BALANCE"
        );
        assertApproxEqRel(vault.getClaimableFees(), feesTaken, ONE_BPS, "FEES NOT AS EXPECTED");
        assertApproxEqRel(dai.balanceOf(ALICE), expectedAliceAmountEnd, ONE_BPS, "END ALICE BALANCE NOT AS EXPECTED");
    }

    function testRedeemFailsWithZeroShares() public {
        vm.prank(ALICE);
        vm.expectRevert(ERR_ZERO_ASSETS);
        vault.redeem(0, ALICE, ALICE);
    }

    function testRedeemFailsWithExceedsMax() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();

        _depositFromUser(ALICE, amount);

        vm.prank(ALICE);
        uint256 maxRedeem = vault.maxRedeem(ALICE);
        vm.expectRevert(ERR_REDEEM_EXCEEDS_MAX);
        vault.redeem(maxRedeem + 1, ALICE, ALICE);
    }

    function testRedeemBasic() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();

        _depositFromUser(ALICE, amount);

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), amount + initialLockDeposit);

        // Redeem instead of withdraw
        vm.startPrank(ALICE);
        vm.expectEmit(true, true, true, true, address(vault));
        emit Withdraw(ALICE, ALICE, ALICE, amount, amount);
        vault.redeem(vault.balanceOf(ALICE), ALICE, ALICE);
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
    }

    function testRedeemATokens() public {
        _depositFromUser(ALICE, ONE);

        vm.startPrank(ALICE);
        vm.expectEmit(true, true, true, true, address(vault));
        emit Withdraw(ALICE, ALICE, ALICE, ONE, ONE);
        vault.redeemAsATokens(ONE, ALICE, ALICE);

        assertEq(aDai.balanceOf(ALICE), ONE);
        assertEq(aDai.balanceOf(address(vault)), initialLockDeposit);
        assertEq(vault.balanceOf(ALICE), 0);
    }

    function testRedeemAfterYieldEarned() public {
        uint256 amount = HUNDRED;
        uint256 adjustedAmount = amount - initialLockDeposit;
        uint256 expectedAliceAmountEnd = adjustedAmount + adjustedAmount;

        _depositFromUser(ALICE, adjustedAmount);

        // still 1:1 exchange rate
        assertEq(vault.convertToShares(amount), amount);
        assertEq(vault.balanceOf(ALICE), adjustedAmount);

        // Increase share/asset exchange rate
        uint256 fee = vault.getFee();
        uint256 amountPlusFee = amount.mulDiv(SCALE, SCALE - fee, MathUpgradeable.Rounding.Up);
        uint256 feesTaken = amountPlusFee - amount;
        _accrueYieldInVault(amountPlusFee);

        // Now 2:1 assets to shares exchange rate
        assertEq(vault.convertToAssets(amount), amount * 2);

        skip(1);

        uint256 aliceMaxRedeemable = vault.maxRedeem(ALICE);
        assertApproxEqRel(vault.convertToAssets(aliceMaxRedeemable), expectedAliceAmountEnd, ONE_BPS);

        vm.startPrank(ALICE);
        vm.expectEmit(true, true, true, true, address(vault));
        emit Withdraw(ALICE, ALICE, ALICE, vault.convertToAssets(aliceMaxRedeemable), adjustedAmount);
        vault.redeem(aliceMaxRedeemable, ALICE, ALICE);
        vm.stopPrank();

        assertEq(
            aDai.balanceOf(address(vault)) - vault.convertToAssets(initialLockDeposit),
            vault.getClaimableFees(),
            "FEES NOT SAME AS VAULT BALANCE"
        );
        assertApproxEqRel(vault.getClaimableFees(), feesTaken, ONE_BPS, "FEES NOT AS EXPECTED");
        assertApproxEqRel(dai.balanceOf(ALICE), expectedAliceAmountEnd, ONE_BPS, "END ALICE BALANCE NOT AS EXPECTED");
    }

    /*//////////////////////////////////////////////////////////////
                                SCENARIOS
    //////////////////////////////////////////////////////////////*/

    function testTwoUsersSameDurationAmountAndYield() public {
        uint256 amount = HUNDRED;
        uint256 timeDeposited = 500 days; // of DeFi summer

        _depositFromUser(ALICE, amount);
        _depositFromUser(BOB, amount);

        uint256 blockTimeBefore = block.timestamp;

        skip(timeDeposited);

        uint256 blockTimeAfter = block.timestamp;

        assertEq(blockTimeAfter, blockTimeBefore + timeDeposited);
        assertEq(vault.maxWithdraw(ALICE), vault.maxWithdraw(BOB));

        _withdrawFromUser(ALICE, 0); //withdraw max
        _withdrawFromUser(BOB, 0); //withdraw max

        assertApproxEqAbs(dai.balanceOf(ALICE), dai.balanceOf(BOB), 1);
    }

    function testTwoUsersSameDurationDiffAmountAndYield() public {
        uint256 amountAlice = HUNDRED;
        uint256 amountBob = 2 * HUNDRED; // Bob deposits double Alice amount
        uint256 timeDeposited = 500 days;

        _depositFromUser(ALICE, amountAlice);
        _depositFromUser(BOB, amountBob);

        uint256 blockTimeBefore = block.timestamp;

        skip(timeDeposited);

        uint256 blockTimeAfter = block.timestamp;

        assertEq(blockTimeAfter, blockTimeBefore + timeDeposited);
        assertGt(vault.maxWithdraw(BOB), vault.maxWithdraw(ALICE));

        _withdrawFromUser(ALICE, 0); //withdraw max
        _withdrawFromUser(BOB, 0); //withdraw max

        uint256 yieldAlice = dai.balanceOf(ALICE) - amountAlice;
        uint256 yieldBob = dai.balanceOf(BOB) - amountBob;

        // Bob should get double the yield
        assertApproxEqRel(yieldBob, 2 * yieldAlice, ONE_BPS);
    }

    function testTwoUsersSameAmountDiffDurationAndYield() public {
        uint256 amount = HUNDRED;
        uint256 timeDepositedAlice = 500 days;
        uint256 timeDepositedBob = 1000 days; // Bob deposits for double time

        _depositFromUser(ALICE, amount);
        _depositFromUser(BOB, amount);

        uint256 blockTimeBefore = block.timestamp;

        skip(timeDepositedAlice);

        uint256 blockTimeAfter = block.timestamp;
        assertEq(blockTimeAfter, blockTimeBefore + timeDepositedAlice);
        assertEq(vault.maxWithdraw(BOB), vault.maxWithdraw(ALICE)); // Equal yield so far

        _withdrawFromUser(ALICE, 0); //withdraw max

        skip(timeDepositedBob - timeDepositedAlice); // spend rest of Bobs time in vault

        blockTimeAfter = block.timestamp;
        assertEq(blockTimeAfter, blockTimeBefore + timeDepositedBob);

        _withdrawFromUser(BOB, 0); //withdraw max

        uint256 yieldAlice = dai.balanceOf(ALICE) - amount;
        uint256 yieldBob = dai.balanceOf(BOB) - amount;

        // Very rough, but assuming stable yields, Bob should get double. Test with 5% margin
        assertApproxEqRel(yieldBob, 2 * yieldAlice, 5 * ONE_PERCENT);
    }

    function testTheeUsersDepositAndWithdrawDiffTimes() public {
        uint256 amount = HUNDRED;
        uint256 timeInterval = 100 days;

        _depositFromUser(ALICE, amount);
        skip(timeInterval);
        _depositFromUser(BOB, amount);
        skip(timeInterval);
        _depositFromUser(CHAD, amount);
        skip(timeInterval);
        _withdrawFromUser(CHAD, 0); //withdraw max
        skip(timeInterval);
        _withdrawFromUser(BOB, 0); //withdraw max
        skip(timeInterval);
        _withdrawFromUser(ALICE, 0); //withdraw max

        uint256 yieldAlice = dai.balanceOf(ALICE) - amount;
        uint256 yieldBob = dai.balanceOf(BOB) - amount;
        uint256 yieldChad = dai.balanceOf(CHAD) - amount;

        // Rough checks of yield diffs, within 1.5% margin
        assertApproxEqRel(yieldBob, 3 * yieldChad, ONE_AND_HALF_PERCENT);
        assertApproxEqRel(yieldAlice, 5 * yieldChad, ONE_AND_HALF_PERCENT);
        assertGt(yieldAlice, yieldBob);
    }
}
