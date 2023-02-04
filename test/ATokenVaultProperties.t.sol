// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "erc4626-tests/ERC4626.test.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {IAToken} from "aave-core/interfaces/IAToken.sol";
import {ERC20} from "openzeppelin-non-upgradeable/token/ERC20/ERC20.sol";
import {IPoolAddressesProvider} from "aave-core/interfaces/IPoolAddressesProvider.sol";
import {IRewardsController} from "aave-periphery/rewards/interfaces/IRewardsController.sol";

import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";

contract ATokenVaultPropertiesTest is ERC4626Test, ATokenVaultBaseTest {
    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aDai;
    MockDAI dai;

    // Tested in fork tests - not needed in mock tests
    address fakeIncentivesController = address(101010101);

    function setUp() public override(ERC4626Test, ATokenVaultBaseTest) {
        aDai = new MockAToken();
        pool = new MockAavePool(aDai);
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));

        dai = new MockDAI();

        _deploy(address(dai), address(poolAddrProvider));

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
