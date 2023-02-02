// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import {IRewardsController} from "aave-periphery/rewards/interfaces/IRewardsController.sol";
import {IPool} from "aave/interfaces/IPool.sol";

contract ATokenVaultForkTest is ATokenVaultBaseTest {
    // Forked tests using Polygon for Aave v3
    uint256 polygonFork;
    uint256 POLYGON_FORK_BLOCK = 35486670;

    ERC20 dai;
    IAToken aDai;

    function setUp() public override {
        polygonFork = vm.createFork(vm.envString("POLYGON_RPC_URL"));
        vm.selectFork(polygonFork);
        vm.rollFork(POLYGON_FORK_BLOCK);

        dai = ERC20(POLYGON_DAI);
        aDai = IAToken(POLYGON_ADAI);

        vaultAssetAddress = address(aDai);

        vm.startPrank(OWNER);
        vault = new ATokenVault(dai, SHARE_NAME, SHARE_SYMBOL, fee, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));
        vm.stopPrank();
    }

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

    function testDeployRevertsFeeTooHigh() public {
        vm.expectRevert(ERR_FEE_TOO_HIGH);
        vault = new ATokenVault(
            dai,
            SHARE_NAME,
            SHARE_SYMBOL,
            SCALE + 1,
            IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER)
        );
    }

    function testDeployRevertsWithUnlistedAsset() public {
        // UNI token is not listed on Aave v3
        address uniToken = 0xb33EaAd8d922B1083446DC23f610c2567fB5180f;

        vm.expectRevert(ERR_ASSET_NOT_SUPPORTED);
        vault = new ATokenVault(
            ERC20(uniToken),
            SHARE_NAME,
            SHARE_SYMBOL,
            fee,
            IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER)
        );
    }

    function testDeployRevertsWithBadPoolAddressProvider() public {
        vm.expectRevert();
        vault = new ATokenVault(dai, SHARE_NAME, SHARE_SYMBOL, fee, IPoolAddressesProvider(address(0)));
    }

    function testNonOwnerCannotWithdrawFees() public {
        uint256 feesAmount = 50 * ONE;
        _deployAndCheckProps();
        _accrueFeesInVault(feesAmount);

        uint256 feesAccrued = vault.getCurrentFees();
        assertGt(feesAccrued, 0); // must have accrued some fees

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

        uint256 feesAccrued = vault.getCurrentFees();
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

    function testDeploySucceedsWithValidParams() public {
        _deployAndCheckProps();
    }

    function testDeployEmitsFeeEvent() public {
        // no indexed fields, just data check (4th param)
        vm.expectEmit(false, false, false, true);
        emit FeeUpdated(0, fee);
        vault = new ATokenVault(dai, SHARE_NAME, SHARE_SYMBOL, fee, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));
    }

    function testOwnerCanWithdrawFees() public {
        uint256 feesAmount = 50 * ONE;
        _deployAndCheckProps();
        _accrueFeesInVault(feesAmount);

        uint256 feesAccrued = vault.getCurrentFees();

        assertGt(feesAccrued, 0); // must have accrued some fees

        vm.startPrank(OWNER);
        vault.withdrawFees(OWNER, feesAccrued);
        vm.stopPrank();

        assertEq(aDai.balanceOf(OWNER), feesAccrued);
        assertEq(vault.getCurrentFees(), 0);
    }

    function testWithdrawFeesEmitsEvent() public {
        uint256 feesAmount = 50 * ONE;
        _deployAndCheckProps();
        _accrueFeesInVault(feesAmount);

        uint256 feesAccrued = vault.getCurrentFees();
        uint256 vaultADaiBalanceBefore = aDai.balanceOf(address(vault));

        assertGt(feesAccrued, 0);

        vm.startPrank(OWNER);
        vm.expectEmit(true, false, false, true, address(vault));
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
        vm.expectEmit(false, false, false, true, address(vault));
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

    function testTotalAssetsReturnsZeroWhenEmpty() public {
        _deployAndCheckProps();
        assertEq(vault.totalAssets(), 0);
    }

    function testTotalAssetsPositiveNoFeesAccrued() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();
        _depositFromUser(ALICE, amount);
        assertEq(vault.totalAssets(), amount);
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

        assertEq(vault.totalAssets(), 0, "Total assets not zero"); // No user funds left in vault, only fees
        assertEq(vault.getCurrentFees(), aDai.balanceOf(address(vault)), "Fees not same as aDAI balance");
        assertGt(vault.getCurrentFees(), 0, "Fees not zero"); // Fees remain
    }

    function testTotalAssetsDepositThenWithdrawWithNoFeesRemaining() public {
        uint256 amount = HUNDRED;
        uint256 feesAmount = 50 * ONE;
        _deployAndCheckProps();

        _accrueFeesInVault(feesAmount);
        _depositFromUser(ALICE, amount);

        uint256 vaultAssetBalance = aDai.balanceOf(address(vault));

        assertApproxEqRel(vault.totalAssets(), vaultAssetBalance - feesAmount, ONE_BPS);

        _withdrawFromUser(ALICE, amount);

        assertEq(vault.totalAssets(), 0, "Total assets not zero"); // No user funds left in vault, only fees
        assertEq(vault.getCurrentFees(), aDai.balanceOf(address(vault)), "Fees not equal to aDAI balance");
        assertGt(vault.getCurrentFees(), 0, "Fees not zero"); // Some fees remain

        _withdrawFees(0); // withdraw all fees

        assertEq(vault.totalAssets(), 0, "Total assets not zero"); // No user funds left in vault, no fees
    }

    function testAccrueYieldUpdatesOnTimestampDiff() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();

        uint256 lastUpdated = vault.getLastUpdated();
        uint256 lastVaultBalance = vault.getLastVaultBalance();

        _depositFromUser(ALICE, amount);
        skip(1);
        _depositFromUser(ALICE, amount);
        // only lastUpdated does NOT change if same timestamp
        // lastVaultBalance is updated separately regardless of timestamp

        assertEq(vault.getLastUpdated(), lastUpdated + 1);
        assertApproxEqRel(vault.getLastVaultBalance(), lastVaultBalance + (2 * amount), ONE_BPS);
    }

    function testAccrueYieldDoesNotUpdateOnSameTimestamp() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();

        uint256 prevTimestamp = block.timestamp;
        uint256 lastUpdated = vault.getLastUpdated();
        uint256 lastVaultBalance = vault.getLastVaultBalance();

        _depositFromUser(ALICE, amount);
        _depositFromUser(ALICE, amount);
        // only lastUpdated does NOT change if same timestamp
        // lastVaultBalance is updated separately regardless of timestamp

        assertEq(block.timestamp, prevTimestamp);
        assertEq(vault.getLastUpdated(), lastUpdated); // this should not have changed as timestamp is same
        assertApproxEqAbs(vault.getLastVaultBalance(), lastVaultBalance + (2 * amount), 1); // This should change on deposit() anyway
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

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT AND MINT
    //////////////////////////////////////////////////////////////*/

    function testDepositFailsWithZeroAssets() public {
        vm.prank(ALICE);
        vm.expectRevert(ERR_ZERO_SHARES);
        vault.deposit(0, ALICE);
    }

    function testDepositSuppliesAave() public {
        _deployAndCheckProps();

        deal(address(dai), ALICE, ONE);

        assertEq(dai.balanceOf(ALICE), ONE);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);
        assertEq(vault.balanceOf(ALICE), 0);

        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vault.deposit(ONE, ALICE);
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), ONE);
        assertEq(vault.balanceOf(ALICE), ONE);
    }

    function testDepositAffectedByExchangeRate() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        // still 1:1 exchange rate
        assertEq(vault.convertToShares(amount), amount);
        assertEq(vault.balanceOf(ALICE), amount);

        // Increase share/asset exchange rate
        _accrueYieldInVault(amount);

        // Now 2:1 assets to shares exchange rate
        assertEq(vault.convertToShares(amount), amount / 2);

        vm.startPrank(ALICE);
        deal(address(dai), ALICE, amount);
        dai.approve(address(vault), amount);
        vault.deposit(amount, ALICE);
        vm.stopPrank();

        assertEq(vault.balanceOf(ALICE), amount + (amount / 2));
    }

    function testMintSuppliesAave() public {
        _deployAndCheckProps();

        deal(address(dai), ALICE, ONE);

        assertEq(dai.balanceOf(ALICE), ONE);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);
        assertEq(vault.balanceOf(ALICE), 0);

        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vault.mint(ONE, ALICE);
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), ONE);
        assertEq(vault.balanceOf(ALICE), ONE);
    }

    function testMintAffectedByExchangeRate() public {
        uint256 amount = HUNDRED;
        _depositFromUser(ALICE, amount);

        // still 1:1 exchange rate
        assertEq(vault.convertToShares(amount), amount);
        assertEq(vault.balanceOf(ALICE), amount);

        // Increase share/asset exchange rate
        _accrueYieldInVault(amount);

        // Now 2:1 assets to shares exchange rate
        assertEq(vault.convertToShares(amount), amount / 2);

        vm.startPrank(ALICE);
        deal(address(dai), ALICE, amount);
        dai.approve(address(vault), amount);
        vault.mint(amount / 2, ALICE);
        vm.stopPrank();

        assertEq(vault.balanceOf(ALICE), amount + (amount / 2));
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW AND REDEEM
    //////////////////////////////////////////////////////////////*/

    function testWithdrawBasic() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();

        _depositFromUser(ALICE, amount);

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), amount);

        _withdrawFromUser(ALICE, amount);

        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);
    }

    function testWithdrawAfterYieldEarned() public {
        uint256 amount = HUNDRED;
        uint256 expectedAliceAmountEnd = amount + (amount - _getFeesOnAmount(amount));
        uint256 expectedFees = _getFeesOnAmount(amount);

        _depositFromUser(ALICE, amount);

        // still 1:1 exchange rate
        assertEq(vault.convertToShares(amount), amount);
        assertEq(vault.balanceOf(ALICE), amount);

        // Increase share/asset exchange rate
        _accrueYieldInVault(amount);

        // Now 2:1 assets to shares exchange rate
        assertEq(vault.convertToAssets(amount), amount * 2);

        skip(1);

        uint256 aliceMaxWithdrawable = vault.maxWithdraw(ALICE);

        assertApproxEqRel(aliceMaxWithdrawable, expectedAliceAmountEnd, ONE_BPS);

        vm.startPrank(ALICE);
        vault.withdraw(aliceMaxWithdrawable, ALICE, ALICE);
        vm.stopPrank();

        assertEq(aDai.balanceOf(address(vault)), vault.getCurrentFees(), "FEES NOT SAME AS VAULT BALANCE");
        assertApproxEqRel(vault.getCurrentFees(), expectedFees, ONE_BPS, "FEES NOT AS EXPECTED");
        assertApproxEqRel(dai.balanceOf(ALICE), expectedAliceAmountEnd, ONE_BPS, "END ALICE BALANCE NOT AS EXPECTED");
    }

    function testRedeemFailsWithZeroShares() public {
        vm.prank(ALICE);
        vm.expectRevert(ERR_ZERO_ASSETS);
        vault.redeem(0, ALICE, ALICE);
    }

    function testRedeemBasic() public {
        uint256 amount = HUNDRED;
        _deployAndCheckProps();

        _depositFromUser(ALICE, amount);

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), amount);

        // Redeem instead of withdraw
        vm.startPrank(ALICE);
        vault.redeem(vault.balanceOf(ALICE), ALICE, ALICE);
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), amount);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);
    }

    function testRedeemAfterYieldEarned() public {
        uint256 amount = HUNDRED;
        uint256 expectedAliceAmountEnd = amount + (amount - _getFeesOnAmount(amount));
        uint256 expectedFees = _getFeesOnAmount(amount);

        _depositFromUser(ALICE, amount);

        // still 1:1 exchange rate
        assertEq(vault.convertToShares(amount), amount);
        assertEq(vault.balanceOf(ALICE), amount);

        // Increase share/asset exchange rate
        _accrueYieldInVault(amount);

        // Now 2:1 assets to shares exchange rate
        assertEq(vault.convertToAssets(amount), amount * 2);

        skip(1);

        uint256 aliceMaxReedemable = vault.maxRedeem(ALICE);

        assertApproxEqRel(vault.convertToAssets(aliceMaxReedemable), expectedAliceAmountEnd, ONE_BPS);

        vm.startPrank(ALICE);
        vault.redeem(aliceMaxReedemable, ALICE, ALICE);
        vm.stopPrank();

        assertEq(aDai.balanceOf(address(vault)), vault.getCurrentFees(), "FEES NOT SAME AS VAULT BALANCE");
        assertApproxEqRel(vault.getCurrentFees(), expectedFees, ONE_BPS, "FEES NOT AS EXPECTED");
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

        // Rough checks of yield diffs, within 1% margin
        assertApproxEqRel(yieldBob, 3 * yieldChad, ONE_PERCENT);
        assertApproxEqRel(yieldAlice, 5 * yieldChad, ONE_PERCENT);
        assertGt(yieldAlice, yieldBob);
    }

    /*//////////////////////////////////////////////////////////////
                                TEST UTILS
    //////////////////////////////////////////////////////////////*/

    function _deployAndCheckProps() public {
        vm.startPrank(OWNER);
        vault = new ATokenVault(dai, SHARE_NAME, SHARE_SYMBOL, fee, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));
        vm.stopPrank();
        assertEq(address(vault.asset()), POLYGON_DAI);
        assertEq(address(vault.A_TOKEN()), POLYGON_ADAI);
        assertEq(address(vault.AAVE_POOL()), POLYGON_AAVE_POOL);
        assertEq(vault.owner(), OWNER);
    }

    function _depositFromUser(address user, uint256 amount) public {
        deal(address(dai), user, amount);

        vm.startPrank(user);
        dai.approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();
    }

    function _withdrawFromUser(address user, uint256 amount) public {
        // If amount is 0, withdraw max for user
        if (amount == 0) amount = vault.maxWithdraw(user);
        vm.startPrank(user);
        vault.withdraw(amount, user, user);
        vm.stopPrank();
    }

    function _withdrawFees(uint256 amount) public {
        if (amount == 0) amount = vault.getCurrentFees();
        vm.startPrank(OWNER);
        vault.withdrawFees(OWNER, amount);
        vm.stopPrank();
    }

    function _accrueYieldInVault(uint256 yieldAmountToAccrue) public {
        require(yieldAmountToAccrue > 0, "TEST: FEES ACCRUED MUST BE > 0");

        deal(address(dai), OWNER, yieldAmountToAccrue);

        vm.startPrank(OWNER);
        dai.approve(POLYGON_AAVE_POOL, yieldAmountToAccrue);
        IPool(POLYGON_AAVE_POOL).supply(address(dai), yieldAmountToAccrue, OWNER, 0);

        // NOTE: reducing by 1 because final vault balance is over by 1 for some reason
        yieldAmountToAccrue -= 1;
        aDai.transfer(address(vault), yieldAmountToAccrue);
        vm.stopPrank();

        assertGt(aDai.balanceOf(address(vault)), yieldAmountToAccrue);
    }

    function _accrueFeesInVault(uint256 feeAmountToAccrue) public {
        require(feeAmountToAccrue > 0, "TEST: FEES ACCRUED MUST BE > 0");
        uint256 daiAmount = feeAmountToAccrue * 5; // Assuming 20% fee

        deal(address(dai), ALICE, daiAmount + ONE);

        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vault.deposit(ONE, ALICE);
        dai.approve(POLYGON_AAVE_POOL, daiAmount);
        IPool(POLYGON_AAVE_POOL).supply(address(dai), daiAmount, ALICE, 0);
        aDai.transfer(address(vault), daiAmount);
        skip(1);

        vault.withdraw(vault.maxWithdraw(ALICE), ALICE, ALICE);
        vm.stopPrank();

        // Fees will be more than specified in param because of interest earned over time in Aave
        assertApproxEqRel(vault.getCurrentFees(), feeAmountToAccrue, ONE_BPS);
    }

    function _getFeesOnAmount(uint256 amount) public view returns (uint256) {
        return (amount * vault.getFee()) / SCALE;
    }
}
