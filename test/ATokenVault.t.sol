// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";

contract ATokenVaultTest is Test {
    // Forked tests using Polygon
    uint256 polygonFork;
    address public constant POLYGON_POOL_ADDRESSES_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    ATokenVault vault;
    ERC20 dai;

    function setUp() public {
        polygonFork = vm.createFork(vm.envString("POLYGON_RPC_URL"));
    }

    function testForkWorks() public {
        vm.selectFork(polygonFork);
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
        // TODO fork dai
        // dai = ERC20();

        vault = new ATokenVault(dai, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));
        // TODO check aToken address and aavePool address set as expected
    }

    /*//////////////////////////////////////////////////////////////
                                SCENARIOS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                TEST UTILS
    //////////////////////////////////////////////////////////////*/
}
