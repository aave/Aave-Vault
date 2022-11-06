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

        daiAddress = address(dai);

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

    function testYieldSplitBasicFOCUS(uint256 yieldEarned) public {
        // TODO refactor

        bound(yieldEarned, 0, 1_000_000 * SCALE);
        // Alice deposits 100 DAI
        deal(address(dai), ALICE, HUNDRED);

        vm.startPrank(ALICE);
        dai.approve(address(vault), HUNDRED);
        vault.mint(HUNDRED, ALICE);
        vm.stopPrank();

        // Simulate yield earned
        _increaseVaultYield(yieldEarned);

        // TODO refactor
        uint256 expectedAssetsTotal = (HUNDRED * (SCALE + yieldEarned)) / SCALE;
        uint256 expectedAssetsUser = (expectedAssetsTotal * (SCALE - fee)) / SCALE;
        uint256 expectedAssetsFees = (expectedAssetsTotal * fee) / SCALE;

        console.log(expectedAssetsTotal);
        console.log(expectedAssetsUser);
        console.log(expectedAssetsFees);

        assertEq(aDai.balanceOf(address(vault)), expectedAssetsTotal);
        assertEq(vault.accumulatedFees(), 0);

        // Alice withdraws ALL assets available
        vm.startPrank(ALICE);
        vault.withdraw(vault.maxWithdraw(ALICE), ALICE, ALICE);
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), expectedAssetsUser);
        assertEq(vault.accumulatedFees(), expectedAssetsFees);
        // assertEq(dai.balanceOf(address(vault)), 0);
        // assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), expectedAssetsFees);
        assertEq(vault.balanceOf(ALICE), 0);
        assertEq(vault.maxWithdraw(ALICE), 0);
    }
}
