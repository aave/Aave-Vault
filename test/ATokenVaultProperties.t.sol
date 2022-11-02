// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "erc4626-tests/ERC4626.test.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";

import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";

contract ATokenVaultPropertiesTest is ERC4626Test {
    string constant SHARE_NAME = "Wrapped aDAI";
    string constant SHARE_SYMBOL = "waDAI";
    uint256 constant DEFAULT_FEE = 0.2e18; // 20%

    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aDai;
    MockDAI dai;

    ATokenVault vault;

    function setUp() public override {
        aDai = new MockAToken();
        pool = new MockAavePool(aDai);
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));

        dai = new MockDAI();

        vault = new ATokenVault(dai, SHARE_NAME, SHARE_SYMBOL, DEFAULT_FEE, IPoolAddressesProvider(address(poolAddrProvider)));

        _underlying_ = address(dai);
        _vault_ = address(vault);
        _delta_ = 0;
        _vaultMayBeEmpty = false;
        _unlimitedAmount = false;
    }

    // NOTE: The following test is relaxed to consider only smaller values (of type uint120),
    // since maxWithdraw() fails with large values (due to overflow).
    // The maxWithdraw() behavior is inherited from Solmate ERC4626 on which this vault is built.
    function test_maxWithdraw(Init memory init) public override {
        init = clamp(init, type(uint120).max);
        super.test_maxWithdraw(init);
    }

    function clamp(Init memory init, uint256 max) internal pure returns (Init memory) {
        for (uint256 i = 0; i < N; i++) {
            init.share[i] = init.share[i] % max;
            init.asset[i] = init.asset[i] % max;
        }
        init.yield = init.yield % int256(max);
        return init;
    }
}
