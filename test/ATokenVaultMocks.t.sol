// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";

import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";

contract ATokenVaultMocksTest is ATokenVaultBaseTest {
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
    }

    function testWithdrawNoFee(uint256 yieldIncrease) public {
        // Redeploy vault with 0% fee
        vault = new ATokenVault(dai, SHARE_NAME, SHARE_SYMBOL, 0, IPoolAddressesProvider(address(poolAddrProvider)));

        // Alice deposits 1 DAI
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

        // Alice withdraws 1 DAI
        vm.startPrank(ALICE);
        vault.withdraw(ONE, ALICE, ALICE);
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), ONE);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);
        assertEq(vault.balanceOf(ALICE), 0);
    }

    function testYieldSplitBasicFOCUS() public {
        // TODO move to fuzz arg
        uint256 yieldEarned = SCALE; // 100%
        // TODO refactor
        uint256 expectedAssetsUser;
        uint256 expectedAssetsFees;

        uint256 startAmount = HUNDRED;

        bound(yieldEarned, 0, 1_000_000 * SCALE);
        // Alice deposits 100 DAI
        deal(address(dai), ALICE, startAmount);

        vm.startPrank(ALICE);
        dai.approve(address(vault), startAmount);
        vault.mint(startAmount, ALICE);
        vm.stopPrank();

        console.log(block.timestamp);

        // Simulate yield earned
        uint256 increaseAmount = _increaseVaultYield(yieldEarned);
        skip(1);

        console.log(block.timestamp);

        // TODO refactor
        uint256 expectedAssetsTotal = startAmount + increaseAmount;
        // uint256 expectedAssetsUser = (expectedAssetsTotal * (SCALE - fee)) / SCALE;
        // uint256 expectedAssetsFees = (expectedAssetsTotal * fee) / SCALE;

        (expectedAssetsFees, expectedAssetsUser) = _expectedFeeSplitOfIncrease(increaseAmount);
        expectedAssetsUser += HUNDRED;

        console.log("New Yield", yieldEarned);
        console.log("Increase", increaseAmount);
        console.log("Total", expectedAssetsTotal);
        console.log("User", expectedAssetsUser);
        console.log("Fees", expectedAssetsFees);
        console.log("Fee Set", fee);

        assertEq(aDai.balanceOf(address(vault)), expectedAssetsTotal);
        // assertEq(vault.accumulatedFees(), 0);

        // Alice withdraws ALL assets available
        vm.startPrank(ALICE);
        vault.withdraw(vault.maxWithdraw(ALICE), ALICE, ALICE);
        vm.stopPrank();

        console.log(block.timestamp);

        assertEq(dai.balanceOf(ALICE), expectedAssetsUser);
        assertEq(vault.accumulatedFees(), expectedAssetsFees);
        // assertEq(dai.balanceOf(address(vault)), 0);
        // assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), expectedAssetsFees);
        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(vault.maxWithdraw(ALICE), 0);
    }
}
