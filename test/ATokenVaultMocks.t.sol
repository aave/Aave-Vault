// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";
import "./utils/Constants.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";

contract ATokenVaultMocksTest is ATokenVaultBaseTest {
    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aDai;
    MockDAI dai;

    function setUp() public override {
        dai = new MockDAI();
        aDai = new MockAToken(address(dai));
        pool = new MockAavePool(aDai);
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));

        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);
        _deploy(address(dai), address(poolAddrProvider));
        // Remove initial supply
        vm.startPrank(address(vault));
        vault.redeem(vault.balanceOf(address(vault)), address(vault), address(vault));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                MAX DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function testMaxDepositAaveUncappedSupply() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);
        uint256 maxDeposit = vault.maxDeposit(ALICE);
        assertEq(maxDeposit, type(uint256).max);
    }

    function testMaxDepositAaveCappedSupply() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_CAPPED_ACTIVE);
        uint256 maxDeposit = vault.maxDeposit(ALICE);
        assertEq(maxDeposit, SUPPLY_CAP_UNSCALED * 10 ** dai.decimals());
    }

    function testMaxDepositAaveInactive() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_INACTIVE);
        uint256 maxDeposit = vault.maxDeposit(ALICE);
        assertEq(maxDeposit, 0);
    }

    function testMaxDepositAaveFrozen() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_FROZEN);
        uint256 maxDeposit = vault.maxDeposit(ALICE);
        assertEq(maxDeposit, 0);
    }

    function testMaxDepositAavePaused() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_PAUSED);
        uint256 maxDeposit = vault.maxDeposit(ALICE);
        assertEq(maxDeposit, 0);
    }

    function testMaxDepositAaveCappedWithSomeSupply() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_CAPPED_ACTIVE);
        uint256 supplyCapWithDecimals = SUPPLY_CAP_UNSCALED * 10 ** dai.decimals();
        assertEq(vault.maxDeposit(ALICE), supplyCapWithDecimals);

        // ALICE deposit TEN
        deal(address(dai), ALICE, TEN);
        vm.startPrank(ALICE);
        dai.approve(address(vault), TEN);
        vault.deposit(TEN, ALICE);
        vm.stopPrank();

        assertEq(vault.maxDeposit(ALICE), supplyCapWithDecimals - TEN);
    }

    function testMaxDepositAaveCappedBelowCurrentSupply() public {
        assertEq(vault.maxDeposit(ALICE), type(uint256).max);

        // ALICE deposit TEN
        deal(address(dai), ALICE, TEN);
        vm.startPrank(ALICE);
        dai.approve(address(vault), TEN);
        vault.deposit(TEN, ALICE);
        vm.stopPrank();

        // SupplyCap of ONE
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_SHORT_CAPPED_ACTIVE);
        assertEq(vault.maxDeposit(ALICE), 0);
    }

    /*//////////////////////////////////////////////////////////////
                                MAX MINT
    //////////////////////////////////////////////////////////////*/

    function testMaxMintAaveUncappedSupply() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);
        uint256 maxMint = vault.maxMint(ALICE);
        assertEq(maxMint, type(uint256).max);
    }

    function testMaxMintAaveCappedSupply() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_CAPPED_ACTIVE);
        uint256 maxMint = vault.maxMint(ALICE);
        assertEq(maxMint, SUPPLY_CAP_UNSCALED * 10 ** dai.decimals());
    }

    function testMaxMintAaveInactive() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_INACTIVE);
        uint256 maxMint = vault.maxMint(ALICE);
        assertEq(maxMint, 0);
    }

    function testMaxMintAaveFrozen() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_FROZEN);
        uint256 maxMint = vault.maxMint(ALICE);
        assertEq(maxMint, 0);
    }

    function testMaxMintAavePaused() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_PAUSED);
        uint256 maxMint = vault.maxMint(ALICE);
        assertEq(maxMint, 0);
    }

    function testMaxMintAaveCappedWithSomeSupply() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_CAPPED_ACTIVE);
        uint256 supplyCapWithDecimals = SUPPLY_CAP_UNSCALED * 10 ** dai.decimals();
        assertEq(vault.maxMint(ALICE), supplyCapWithDecimals);

        // ALICE deposit TEN
        deal(address(dai), ALICE, TEN);
        vm.startPrank(ALICE);
        dai.approve(address(vault), TEN);
        vault.deposit(TEN, ALICE);
        vm.stopPrank();

        assertEq(vault.maxMint(ALICE), supplyCapWithDecimals - TEN);
    }

    function testMaxMintAaveCappedBelowCurrentSupply() public {
        assertEq(vault.maxMint(ALICE), type(uint256).max);

        // ALICE deposit TEN
        deal(address(dai), ALICE, TEN);
        vm.startPrank(ALICE);
        dai.approve(address(vault), TEN);
        vault.deposit(TEN, ALICE);
        vm.stopPrank();

        // SupplyCap of ONE
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_SHORT_CAPPED_ACTIVE);
        assertEq(vault.maxMint(ALICE), 0);
    }

    /*//////////////////////////////////////////////////////////////
                                MAX WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testMaxWithdrawAaveMoreThanEnoughLiquidity() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);

        // ALICE deposit ONE
        deal(address(dai), ALICE, ONE);
        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vault.deposit(ONE, ALICE);
        vm.stopPrank();

        // Pool utilization is 2*ONE
        vm.mockCall(address(dai), abi.encodeWithSelector(dai.balanceOf.selector, address(aDai)), abi.encode(2 * ONE));

        uint256 maxWithdraw = vault.maxWithdraw(ALICE);
        assertEq(maxWithdraw, ONE);
    }

    function testMaxWithdrawAaveEnoughLiquidity() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);

        // ALICE deposit ONE
        deal(address(dai), ALICE, ONE);
        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vault.deposit(ONE, ALICE);
        vm.stopPrank();

        // Pool utilization is ONE
        vm.mockCall(address(dai), abi.encodeWithSelector(dai.balanceOf.selector, address(aDai)), abi.encode(ONE));

        uint256 maxWithdraw = vault.maxWithdraw(ALICE);
        assertEq(maxWithdraw, ONE);
    }

    function testMaxWithdrawAaveNotEnoughLiquidity() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);

        // ALICE deposit ONE
        deal(address(dai), ALICE, ONE);
        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vault.deposit(ONE, ALICE);
        vm.stopPrank();

        // Pool utilization is ONE - 1
        vm.mockCall(address(dai), abi.encodeWithSelector(dai.balanceOf.selector, address(aDai)), abi.encode(ONE - 1));

        uint256 maxWithdraw = vault.maxWithdraw(ALICE);
        assertEq(maxWithdraw, ONE - 1);
    }

    function testMaxWithdrawAaveNoLiquidity() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);

        // ALICE deposit ONE
        deal(address(dai), ALICE, ONE);
        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vault.deposit(ONE, ALICE);
        vm.stopPrank();

        // Pool utilization is 0
        vm.mockCall(address(dai), abi.encodeWithSelector(dai.balanceOf.selector, address(aDai)), abi.encode(0));

        uint256 maxWithdraw = vault.maxWithdraw(ALICE);
        assertEq(maxWithdraw, 0);
    }

    function testMaxWithdrawAaveInactive() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_INACTIVE);
        uint256 maxWithdraw = vault.maxWithdraw(ALICE);
        assertEq(maxWithdraw, 0);
    }

    function testMaxWithdrawAavePaused() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_PAUSED);
        uint256 maxWithdraw = vault.maxWithdraw(ALICE);
        assertEq(maxWithdraw, 0);
    }

    /*//////////////////////////////////////////////////////////////
                                MAX REDEEM
    //////////////////////////////////////////////////////////////*/

    function testMaxRedeemAaveMoreThanEnoughLiquidity() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);

        // ALICE deposit ONE
        deal(address(dai), ALICE, ONE);
        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vault.deposit(ONE, ALICE);
        vm.stopPrank();

        // Pool utilization is 2*ONE
        vm.mockCall(address(dai), abi.encodeWithSelector(dai.balanceOf.selector, address(aDai)), abi.encode(2 * ONE));
        uint256 maxRedeem = vault.maxRedeem(ALICE);
        assertEq(maxRedeem, vault.convertToShares(ONE));
    }

    function testMaxRedeemAaveEnoughLiquidity() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);

        // ALICE deposit ONE
        deal(address(dai), ALICE, ONE);
        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vault.deposit(ONE, ALICE);
        vm.stopPrank();

        // Pool utilization is ONE
        vm.mockCall(address(dai), abi.encodeWithSelector(dai.balanceOf.selector, address(aDai)), abi.encode(ONE));
        uint256 maxRedeem = vault.maxRedeem(ALICE);
        assertEq(maxRedeem, vault.convertToShares(ONE));
    }

    function testMaxRedeemAaveNotEnoughLiquidity() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);

        // ALICE deposit ONE
        deal(address(dai), ALICE, ONE);
        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vault.deposit(ONE, ALICE);
        vm.stopPrank();

        // Pool utilization is ONE - 1
        vm.mockCall(address(dai), abi.encodeWithSelector(dai.balanceOf.selector, address(aDai)), abi.encode(ONE - 1));
        uint256 maxRedeem = vault.maxRedeem(ALICE);
        assertEq(maxRedeem, vault.convertToShares(ONE - 1));
    }

    function testMaxRedeemAaveNoLiquidity() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);

        // ALICE deposit ONE
        deal(address(dai), ALICE, ONE);
        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vault.deposit(ONE, ALICE);
        vm.stopPrank();

        // Pool utilization is 0
        vm.mockCall(address(dai), abi.encodeWithSelector(dai.balanceOf.selector, address(aDai)), abi.encode(0));
        uint256 maxRedeem = vault.maxRedeem(ALICE);
        assertEq(maxRedeem, 0);
    }

    function testMaxRedeemAaveInactive() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_INACTIVE);
        uint256 maxRedeem = vault.maxRedeem(ALICE);
        assertEq(maxRedeem, 0);
    }

    function testMaxRedeemAavePaused() public {
        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_PAUSED);
        uint256 maxRedeem = vault.maxRedeem(ALICE);
        assertEq(maxRedeem, 0);
    }
}
