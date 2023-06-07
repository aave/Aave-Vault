// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {MathUpgradeable} from "@openzeppelin-upgradeable/utils/math/MathUpgradeable.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IACLManager} from "@aave-v3-core/interfaces/IACLManager.sol";
import {ATokenVaultForkBaseTest} from "./ATokenVaultForkBaseTest.t.sol";
import {ATokenVault} from "../src/ATokenVault.sol";

contract ATokenVaultEdge is ATokenVaultForkBaseTest {
    using MathUpgradeable for uint256;

    // This test demonstrates a problematic scenario if the initial deposit is too little.
    function testLowInitialDepositLock() public {
        _deploy(POLYGON_DAI, POLYGON_POOL_ADDRESSES_PROVIDER, 1);

        _transferFromUser(OWNER, 2);

        _depositFromUser(ALICE, 201);
        assertEq(vault.balanceOf(ALICE), 67);

        _depositFromUser(BOB, 200);
        assertEq(vault.balanceOf(BOB), 66);

        _transferFromUser(OWNER, 8);

        _redeemFromUser(ALICE, 67);
        assertEq(vault.balanceOf(ALICE), 0);

        vm.prank(BOB);
        vault.redeem(66, BOB, BOB);
        assertEq(vault.balanceOf(BOB), 0);
    }

    function testCalculationClaimableFees() public {
        /**
         * This test ensure the calculation of fees is always correct and up-to-date, no matter
         * the action and duration (if same block).
         * - ATokens sent to the vault are considered as yield.
         * - Yield can be increased more than once in same block.
         */

        // Remove initial lock deposit
        vm.startPrank(address(vault));
        vault.redeem(vault.balanceOf(address(vault)), address(1), address(vault));
        vm.stopPrank();

        // Bob deposits 1000 tokens, no new yield
        uint256 oldYield = aDai.balanceOf(address(vault));
        uint256 oldFees = vault.getClaimableFees();
        _depositFromUser(BOB, 1000);
        assertEq(oldYield + 1000, aDai.balanceOf(address(vault)), "unexpected yield after deposit");
        assertEq(oldFees, vault.getClaimableFees(), "unexpected fees after deposit");
        oldYield = aDai.balanceOf(address(vault));
        oldFees = vault.getClaimableFees();

        // User deposit and redeem, no new yield
        _depositFromUser(address(0x222), 1_000_000e18);
        _withdrawFromUser(address(0x222), 0);
        assertEq(vault.balanceOf(address(0x222)), 0);
        assertEq(oldYield, aDai.balanceOf(address(vault)), "unexpected yield after user");
        assertEq(oldFees, vault.getClaimableFees(), "unexpected fees after user");
        oldYield = aDai.balanceOf(address(vault));
        oldFees = vault.getClaimableFees();

        // Gift to the vault
        _accrueYieldInVault(100);

        // Increase yield in the Aave Protocol by accumulating yield to Portals
        uint256 currentFees = vault.getClaimableFees();
        uint256 currentIndex = IPool(POLYGON_AAVE_POOL).getReserveNormalizedIncome(address(dai));
        uint256 currentBalance = vault.ATOKEN().balanceOf(address(vault));
        // Using portals
        address BRIDGE = address(0xb0b0);
        uint256 bridgeMint = 40_000_000e18;
        // Mock call `isBridge`
        address aclManagerAddress = vault.AAVE_POOL().ADDRESSES_PROVIDER().getACLManager();
        IACLManager aclManager = IACLManager(aclManagerAddress);
        vm.mockCall(address(aclManagerAddress), abi.encodeWithSelector(aclManager.isBridge.selector, BRIDGE), abi.encode(true));
        vm.startPrank(BRIDGE);
        deal(address(dai), BRIDGE, bridgeMint);
        dai.approve(POLYGON_AAVE_POOL, bridgeMint);
        IPool(POLYGON_AAVE_POOL).backUnbacked(address(dai), 0, bridgeMint);
        vm.stopPrank();

        uint256 newIndex = IPool(POLYGON_AAVE_POOL).getReserveNormalizedIncome(address(dai));
        uint256 newBalance = vault.ATOKEN().balanceOf(address(vault));
        assertLt(currentIndex, newIndex, "unexpected change in index");
        assertLt(currentBalance, newBalance, "unexpected change in balance");
        uint256 newFees = (newBalance - currentBalance).mulDiv(vault.getFee(), SCALE, MathUpgradeable.Rounding.Down);
        // 1 wei imprecision due to AToken nature
        assertApproxEqAbs(vault.getClaimableFees(), currentFees + newFees, 1, "claimable fees are not up to date");
        currentFees = vault.getClaimableFees();

        // Same fees as block before
        vm.warp(block.timestamp + 1);
        assertEq(vault.getClaimableFees(), currentFees, "claimable fees are not up to date");
    }
}
