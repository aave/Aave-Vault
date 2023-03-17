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
    uint256 POLYGON_FORK_BLOCK = 35486670;

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
