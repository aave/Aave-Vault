// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";

contract ATokenVaultForkTest is ATokenVaultBaseTest {
    // Forked tests using Polygon for Aave v3

    uint256 polygonFork;

    ERC20 dai;
    IAToken aDai;

    function setUp() public override {
        polygonFork = vm.createFork(vm.envString("POLYGON_RPC_URL"));
        vm.selectFork(polygonFork);
        dai = ERC20(POLYGON_DAI);
        aDai = IAToken(POLYGON_ADAI);

        daiAddress = address(dai);

        vault = new ATokenVault(
            dai,
            SHARE_NAME,
            SHARE_SYMBOL,
            DEFAULT_FEE,
            IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER)
        );
    }

    function testForkWorks() public {
        assertEq(vm.activeFork(), polygonFork);
    }

    /*//////////////////////////////////////////////////////////////
                                NEGATIVES
    //////////////////////////////////////////////////////////////*/

    function testDeployRevertsWithUnlistedAsset() public {}

    function testDeployRevertsWithBadPoolAddrProvider() public {}

    /*//////////////////////////////////////////////////////////////
                                POSITIVES
    //////////////////////////////////////////////////////////////*/

    function testDeploySucceedsWithValidParams() public {
        _deployAndCheckProps();
    }

    function testDepositSuppliesAave() public {
        _deployAndCheckProps();

        deal(address(dai), ALICE, ONE);

        assertEq(dai.balanceOf(ALICE), ONE);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), 0);
        assertEq(vault.balanceOf(ALICE), 0);

        vm.startPrank(ALICE);
        dai.approve(address(vault), ONE);
        vault.deposit(ONE, ALICE);
        vm.stopPrank();

        assertEq(dai.balanceOf(ALICE), 0);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(aDai.balanceOf(ALICE), 0);
        assertEq(aDai.balanceOf(address(vault)), ONE);
        assertEq(vault.balanceOf(ALICE), ONE);
    }

    function testMintSuppliesAave() public {
        _deployAndCheckProps();

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
    }

    function testWithdrawNoFee() public {
        // Redeploy vault with 0% fee
        vault = new ATokenVault(dai, SHARE_NAME, SHARE_SYMBOL, 0, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));

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

    function testWithdrawWithFee() public {}

    function testRedeemNoFee() public {}

    function testRedeemWithFee() public {}

    /*//////////////////////////////////////////////////////////////
                                SCENARIOS
    //////////////////////////////////////////////////////////////*/

    function testFuzzMultiDepositTwoUsers() public {}

    function testFuzzMultiMintTwoUsers() public {}

    function testFuzzMultiWithdrawTwoUsers() public {}

    function testFuzzMultiRedeemTwoUsers() public {}

    function testFuzzDepositAndWithdraw() public {}

    /*//////////////////////////////////////////////////////////////
                                TEST UTILS
    //////////////////////////////////////////////////////////////*/

    function _deployAndCheckProps() public {
        vault = new ATokenVault(
            dai,
            SHARE_NAME,
            SHARE_SYMBOL,
            DEFAULT_FEE,
            IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER)
        );
        assertEq(address(vault.asset()), POLYGON_DAI);
        assertEq(address(vault.aToken()), POLYGON_ADAI);
        assertEq(address(vault.aavePool()), POLYGON_AAVE_POOL);
    }
}
