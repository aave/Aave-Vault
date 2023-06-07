// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./utils/Constants.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IAToken} from "@aave-v3-core/interfaces/IAToken.sol";
import {IPoolDataProvider} from "@aave-v3-core/interfaces/IPoolDataProvider.sol";
import {DataTypes as AaveDataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {WadRayMath} from "@aave-v3-core/protocol/libraries/math/WadRayMath.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

contract ATokenVaultForkBaseTest is ATokenVaultBaseTest {
    // Forked tests using Polygon for Aave v3
    uint256 polygonFork;
    uint256 POLYGON_FORK_BLOCK = 42535610;

    ERC20 dai;
    IAToken aDai;

    function setUp() public virtual override {
        polygonFork = vm.createFork(vm.envString("POLYGON_RPC_URL"));
        vm.selectFork(polygonFork);
        vm.rollFork(POLYGON_FORK_BLOCK);

        dai = ERC20(POLYGON_DAI);
        aDai = IAToken(POLYGON_ADAI);

        vaultAssetAddress = address(aDai);

        _deploy(POLYGON_DAI, POLYGON_POOL_ADDRESSES_PROVIDER);
    }

    /*//////////////////////////////////////////////////////////////
                                TEST UTILS
    //////////////////////////////////////////////////////////////*/

    function _deployAndCheckProps() public {
        _deploy(POLYGON_DAI, POLYGON_POOL_ADDRESSES_PROVIDER);
        assertEq(address(vault.asset()), POLYGON_DAI);
        assertEq(address(vault.ATOKEN()), POLYGON_ADAI);
        assertEq(address(vault.AAVE_POOL()), POLYGON_AAVE_POOL);
        assertEq(vault.owner(), OWNER);
    }

    function _transferFromUser(address user, uint256 amount) public {
        deal(address(dai), user, amount);
        vm.startPrank(user);
        dai.approve(POLYGON_AAVE_POOL, amount);
        IPool(POLYGON_AAVE_POOL).supply(address(dai), amount, address(vault), 0);
        vm.stopPrank();
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

    function _redeemFromUser(address user, uint256 shares) public {
        if (shares == 0) shares = vault.maxRedeem(user);
        vm.startPrank(user);
        vault.redeem(shares, user, user);
        vm.stopPrank();
    }

    function _withdrawFees(uint256 amount) public {
        if (amount == 0) amount = vault.getClaimableFees();
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
        uint256 daiAmount = (feeAmountToAccrue * SCALE) / vault.getFee();

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
        assertApproxEqRel(vault.getClaimableFees(), feeAmountToAccrue, ONE_BPS);
    }

    function _getFeesOnAmount(uint256 amount) public view returns (uint256) {
        return (amount * vault.getFee()) / SCALE;
    }

    function _maxDaiSuppliableToAave() internal view returns (uint256) {
        AaveDataTypes.ReserveData memory reserveData = IPool(POLYGON_AAVE_POOL).getReserveData(POLYGON_DAI);

        uint256 reserveConfigMap = reserveData.configuration.data;
        (, uint256 supplyCap) = IPoolDataProvider(POLYGON_DATA_PROVIDER).getReserveCaps(POLYGON_DAI);

        if (
            (reserveConfigMap & ~AAVE_ACTIVE_MASK == 0) ||
            (reserveConfigMap & ~AAVE_FROZEN_MASK != 0) ||
            (reserveConfigMap & ~AAVE_PAUSED_MASK != 0)
        ) {
            return 0;
        } else if (supplyCap == 0) {
            return type(uint256).max;
        } else {
            return
                (supplyCap * 10 ** dai.decimals()) -
                WadRayMath.rayMul(
                    (aDai.scaledTotalSupply() + uint256(reserveData.accruedToTreasury)),
                    reserveData.liquidityIndex
                );
        }
    }
}
