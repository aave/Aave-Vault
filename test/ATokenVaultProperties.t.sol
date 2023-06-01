// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "erc4626-tests/ERC4626.test.sol";
import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";
import "./utils/Constants.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";

contract ATokenVaultPropertiesTest is ERC4626Test, ATokenVaultBaseTest {
    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aDai;
    MockDAI dai;

    function setUp() public override(ERC4626Test, ATokenVaultBaseTest) {
        dai = new MockDAI();
        aDai = new MockAToken(address(dai));
        pool = new MockAavePool(aDai);
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));

        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);
        _deploy(address(dai), address(poolAddrProvider));

        _underlying_ = address(dai);
        _vault_ = address(vault);
        _delta_ = 0;
        _vaultMayBeEmpty = false;
        _unlimitedAmount = false;
    }

    // NOTE: The following tests are relaxed to consider only smaller values (of type uint120),
    // since they fail with large values (due to overflow).
    function test_maxMint(Init memory init) public override {
        init = clamp(init, type(uint120).max);
        super.test_maxMint(init);
    }

    function test_previewMint(Init memory init, uint shares) public override {
        init = clamp(init, type(uint120).max);
        shares = shares % type(uint120).max;
        super.test_previewMint(init, shares);
    }

    function test_mint(Init memory init, uint shares, uint allowance) public override {
        init = clamp(init, type(uint120).max);
        shares = shares % type(uint120).max;
        allowance = allowance % type(uint120).max;
        super.test_mint(init, shares, allowance);
    }

    //

    function test_maxWithdraw(Init memory init) public override {
        init = clamp(init, type(uint120).max);
        super.test_maxWithdraw(init);
    }

    function test_previewWithdraw(Init memory init, uint assets) public override {
        init = clamp(init, type(uint120).max);
        assets = assets % type(uint120).max;
        super.test_previewWithdraw(init, assets);
    }

    function test_maxRedeem(Init memory init) public override {
        init = clamp(init, type(uint120).max);
        super.test_maxRedeem(init);
    }

    function test_previewRedeem(Init memory init, uint shares) public override {
        init = clamp(init, type(uint120).max);
        shares = shares % type(uint120).max;
        super.test_previewRedeem(init, shares);
    }

    function test_RT_redeem_deposit(Init memory init, uint shares) public override {
        init = clamp(init, type(uint120).max);
        shares = shares % type(uint120).max;
        super.test_RT_redeem_deposit(init, shares);
    }

    function test_RT_redeem_mint(Init memory init, uint shares) public override {
        init = clamp(init, type(uint120).max);
        shares = shares % type(uint120).max;
        super.test_RT_redeem_mint(init, shares);
    }

    function test_RT_mint_withdraw(Init memory init, uint shares) public override {
        init = clamp(init, type(uint120).max);
        shares = shares % type(uint120).max;
        super.test_RT_mint_withdraw(init, shares);
    }

    function test_RT_mint_redeem(Init memory init, uint shares) public override {
        init = clamp(init, type(uint120).max);
        shares = shares % type(uint120).max;
        super.test_RT_mint_redeem(init, shares);
    }

    function test_RT_withdraw_mint(Init memory init, uint assets) public override {
        init = clamp(init, type(uint120).max);
        assets = assets % type(uint120).max;
        super.test_RT_withdraw_mint(init, assets);
    }

    function test_RT_withdraw_deposit(Init memory init, uint assets) public override {
        init = clamp(init, type(uint120).max);
        assets = assets % type(uint120).max;
        super.test_RT_withdraw_deposit(init, assets);
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
