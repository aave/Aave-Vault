// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract ATokenVaultBaseTest is Test {
    // Forked tests using Polygon for Aave v3
    address constant POLYGON_DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address constant POLYGON_ADAI = 0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE;
    address constant POLYGON_AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address constant POLYGON_POOL_ADDRESSES_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;

    uint256 constant SCALE = 1e18;
    uint256 constant ONE = 1e18;
    uint256 constant TEN = 10e18;
    uint256 constant HUNDRED = 100e18;

    address constant ALICE = address(123);
    address constant BOB = address(456);

    string constant SHARE_NAME = "Wrapped aDAI";
    string constant SHARE_SYMBOL = "waDAI";
    uint256 constant DEFAULT_FEE = 0.2e18; // 20%

    ATokenVault vault;
    address daiAddress; // must be set in setUp() of each test file

    function setUp() public virtual {}

    function _increaseVaultYield(uint256 newYieldPercentage) internal {
        uint256 currentTokenBalance = ERC20(daiAddress).balanceOf(address(vault));
        uint256 newTokenAmount = ((SCALE + newYieldPercentage) * currentTokenBalance) / SCALE;
        deal(daiAddress, address(vault), newTokenAmount);
    }

    function _increaseVaultYieldWithTokens(uint256 newTokenAmount) internal {
        require(daiAddress != address(0), "BaseTest: daiAddress not set");
        deal(daiAddress, address(vault), newTokenAmount);
    }
}
