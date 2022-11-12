// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {ATokenVaultBaseTest, IATokenVault} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "aave/interfaces/IPool.sol";

contract ATokenVaultForkTest is ATokenVaultBaseTest {
    // Forked tests using Polygon for Aave v3
    uint256 polygonFork;
    uint256 POLYGON_FORK_BLOCK = 35486670;

    ERC20 dai;
    IAToken aDai;

    function setUp() public override {
        polygonFork = vm.createFork(vm.envString("POLYGON_RPC_URL"));
        vm.selectFork(polygonFork);
        vm.rollFork(POLYGON_FORK_BLOCK);

        dai = ERC20(POLYGON_DAI);
        aDai = IAToken(POLYGON_ADAI);

        vaultAssetAddress = address(aDai);

        vm.startPrank(OWNER);
        vault = new ATokenVault(dai, SHARE_NAME, SHARE_SYMBOL, fee, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        POLYGON FORK TESTS
    //////////////////////////////////////////////////////////////*/

    function testForkWorks() public {
        assertEq(vm.activeFork(), polygonFork);
    }

    function testForkAtExpectedBlock() public {
        assertEq(block.number, POLYGON_FORK_BLOCK);
    }

    /*//////////////////////////////////////////////////////////////
                                NEGATIVES
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                POSITIVES
    //////////////////////////////////////////////////////////////*/

    function testDepositWithSig() public {
        uint256 amount = HUNDRED;
        deal(address(dai), ALICE, amount);

        vm.startPrank(ALICE);
        dai.approve(address(vault), amount); // TODO remove this when ready
        vault.deposit(amount, ALICE);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT AND MINT
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW AND REDEEM
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                SCENARIOS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                TEST UTILS
    //////////////////////////////////////////////////////////////*/
}
