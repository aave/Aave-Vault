// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import {IRewardsController} from "aave-periphery/rewards/interfaces/IRewardsController.sol";

import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";

contract ATokenVaultPropertiesTest is ATokenVaultBaseTest {
    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aDai;
    MockDAI dai;

    // Tested in fork tests - not needed in mock tests
    address fakeIncentivesController = address(101010101);

    function setUp() public override {
        aDai = new MockAToken();
        pool = new MockAavePool(aDai);
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));

        dai = new MockDAI();

        vault = new ATokenVault(
            dai,
            SHARE_NAME,
            SHARE_SYMBOL,
            fee,
            IPoolAddressesProvider(address(poolAddrProvider)),
            IRewardsController(fakeIncentivesController)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                MAX DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function testMaxDepositAaveUncappedSupply() public {
        uint256 maxDeposit = vault.maxDeposit(ALICE);
        assertEq(maxDeposit, type(uint256).max);
    }

    function testMaxDepositAaveCappedSupply() public {}

    function testMaxDepositAaveNotActive() public {}

    function testMaxDepositAaveFrozen() public {}

    function testMaxDepositAavePaused() public {}

    /*//////////////////////////////////////////////////////////////
                                MAX MINT
    //////////////////////////////////////////////////////////////*/
}
