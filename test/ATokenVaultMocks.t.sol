// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {IAToken} from "@aave-v3-core/interfaces/IAToken.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {IRewardsController} from "@aave-v3-periphery/rewards/interfaces/IRewardsController.sol";

import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";
import "./mocks/MocksConstants.sol";

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

        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);
        _deploy(address(dai), address(poolAddrProvider));
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
        assertEq(maxDeposit, SUPPLY_CAP_UNSCALED * 10**dai.decimals());
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
        assertEq(maxMint, SUPPLY_CAP_UNSCALED * 10**dai.decimals());
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
}
