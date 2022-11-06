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

    function testWithdrawNoFee() public {
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

    function testYieldSplitBasic(uint256 yieldEarned) public {
        yieldEarned = bound(yieldEarned, 0, type(uint128).max);

        uint256 expectedAssetsUser;
        uint256 expectedAssetsFees;
        uint256 startAmount = HUNDRED;

        // Alice deposits 100 DAI
        deal(address(dai), ALICE, startAmount);

        vm.startPrank(ALICE);
        dai.approve(address(vault), startAmount);
        vault.mint(startAmount, ALICE);
        vm.stopPrank();

        _logVaultBalances(ALICE, "DEPOSITED");

        // Simulate yield earned
        uint256 increaseAmount = _increaseVaultYield(yieldEarned);
        skip(1);

        uint256 expectedAssetsTotal = startAmount + increaseAmount;
        (expectedAssetsFees, expectedAssetsUser) = _expectedFeeSplitOfIncrease(increaseAmount);
        expectedAssetsUser += startAmount; // above returns only yield split, add back startAmount

        assertEq(aDai.balanceOf(address(vault)), expectedAssetsTotal);
        assertEq(vault.accumulatedFees(), 0);

        // Alice withdraws ALL assets available
        vm.startPrank(ALICE);
        vault.withdraw(vault.maxWithdraw(ALICE), ALICE, ALICE);
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), expectedAssetsUser);
        assertEq(vault.accumulatedFees(), expectedAssetsFees);
        assertEq(aDai.balanceOf(address(vault)), expectedAssetsFees);
        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(vault.maxWithdraw(ALICE), 0);
    }

    // TEST UTILS and OVERRIDES

    function _increaseVaultYield(uint256 newYieldPercentage) internal override returns (uint256 increaseAmount) {
        uint256 currentTokenBalance = ERC20(vaultAssetAddress).balanceOf(address(vault));
        increaseAmount = (((SCALE + newYieldPercentage) * currentTokenBalance) / SCALE) - currentTokenBalance;
        _mintADai(address(vault), increaseAmount);
    }

    // NOTE: Use this instead of Foundry's deal cheatcode for mocked aTokens
    // To ensure mocked Aave pool stays solvent - underlying increases when new
    // aTokens are minted.
    function _mintADai(address recipient, uint256 amount) internal {
        aDai.mint(recipient, amount);
        dai.mint(address(pool), amount);
    }
}
