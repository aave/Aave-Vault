// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";
import {ERC20} from "openzeppelin-non-upgradeable/token/ERC20/ERC20.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import {IRewardsController} from "aave-periphery/rewards/interfaces/IRewardsController.sol";

import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";

import "../src/libraries/Constants.sol";

contract ATokenVaultMocksTest is ATokenVaultBaseTest {
    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aDai;
    MockDAI dai;

    uint256 internal constant IS_ACTIVE_START_BIT_POSITION = 56;
    uint256 internal constant IS_FROZEN_START_BIT_POSITION = 57;
    uint256 internal constant IS_PAUSED_START_BIT_POSITION = 60;
    uint256 internal constant SUPPLY_CAP_UNSCALED = 420;

    uint256 internal constant RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE = (0 & AAVE_ACTIVE_MASK) | (1 << IS_ACTIVE_START_BIT_POSITION);

    uint256 internal constant RESERVE_CONFIG_MAP_CAPPED_ACTIVE =
        (RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE & AAVE_SUPPLY_CAP_MASK) | (SUPPLY_CAP_UNSCALED << AAVE_SUPPLY_CAP_BIT_POSITION);

    uint256 internal constant RESERVE_CONFIG_MAP_INACTIVE = (0 & AAVE_ACTIVE_MASK) | (0 << IS_ACTIVE_START_BIT_POSITION);

    uint256 internal constant RESERVE_CONFIG_MAP_FROZEN =
        (RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE & AAVE_FROZEN_MASK) | (1 << IS_FROZEN_START_BIT_POSITION);

    uint256 internal constant RESERVE_CONFIG_MAP_PAUSED =
        (RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE & AAVE_PAUSED_MASK) | (1 << IS_PAUSED_START_BIT_POSITION);

    // Tested in fork tests - not needed in mock tests
    address fakeIncentivesController = address(101010101);

    function setUp() public override {
        aDai = new MockAToken();
        pool = new MockAavePool(aDai);
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));

        dai = new MockDAI();

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
