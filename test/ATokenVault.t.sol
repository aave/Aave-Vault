// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";

contract ATokenVaultTest is Test {
    // Forked tests using Polygon for Aave v3
    address public constant POLYGON_DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address public constant POLYGON_ADAI = 0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE;
    address public constant POLYGON_AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant POLYGON_POOL_ADDRESSES_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    uint256 polygonFork;
    ATokenVault vault;
    ERC20 dai;

    function setUp() public {
        polygonFork = vm.createFork(vm.envString("POLYGON_RPC_URL"));
        vm.selectFork(polygonFork);
        dai = ERC20(POLYGON_DAI);
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
        vault = new ATokenVault(dai, IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER));
        assertEq(address(vault.asset()), POLYGON_DAI);
        assertEq(address(vault.aToken()), POLYGON_ADAI);
        assertEq(address(vault.aavePool()), POLYGON_AAVE_POOL);
    }

    /*//////////////////////////////////////////////////////////////
                                SCENARIOS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                TEST UTILS
    //////////////////////////////////////////////////////////////*/
}
