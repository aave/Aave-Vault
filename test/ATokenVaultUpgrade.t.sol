// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./utils/Constants.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {ATokenVaultForkBaseTest} from "./ATokenVaultForkBaseTest.t.sol";
import {ProxyUtils} from "./utils/ProxyUtils.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {ATokenVaultV2} from "../src/ATokenVaultV2.sol";

contract ATokenVaultUpgradeTest is ATokenVaultForkBaseTest {
    function testUpgrade() public {
        ProxyUtils pu = new ProxyUtils();
        // Check existing initialization
        vm.expectRevert("Initializable: contract is already initialized");
        vault.initialize(OWNER, fee, SHARE_NAME, SHARE_SYMBOL, 1);
        address oldImple = pu.getImplementation(address(vault));

        ATokenVaultV2 vaultV2 = new ATokenVaultV2(
            POLYGON_DAI,
            referralCode,
            IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER)
        );
        vm.expectRevert("Initializable: contract is already initialized");
        vaultV2.initialize(OWNER, fee, SHARE_NAME, SHARE_SYMBOL, 1);
        vm.expectRevert("Initializable: contract is already initialized");
        vaultV2.initializeV2();

        bytes memory data = abi.encodeWithSelector(ATokenVaultV2.initializeV2.selector);
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(vault)));

        vm.record();

        vm.prank(PROXY_ADMIN);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Upgraded(address(vaultV2));
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Initialized(2);
        proxy.upgradeToAndCall(address(vaultV2), data);

        (, bytes32[] memory writes) = vm.accesses(address(vault));
        assertEq(writes.length, 3);

        address newImple = pu.getImplementation(address(vault));
        assertTrue(oldImple != newImple);
        assertEq(newImple, address(vaultV2));
    }

    function testUpgradeWithUsers() public {
        _depositFromUser(ALICE, 10e18);
        _accrueYieldInVault(20e18);
        skip(200);
        _depositFromUser(BOB, 1_000e18);
        skip(100);
        _withdrawFromUser(ALICE, 5e18);
        _depositFromUser(ALICE, 20_000e18);
        skip(1);

        // Store state
        uint256 aliceBalanceBefore = vault.balanceOf(ALICE);
        uint256 bobBalanceBefore = vault.balanceOf(BOB);
        uint256 aliceRedeemBefore = vault.previewRedeem(aliceBalanceBefore);
        uint256 bobRedeemBefore = vault.previewRedeem(bobBalanceBefore);
        uint256 feesBefore = vault.getClaimableFees();
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();

        ATokenVaultV2 newImple = new ATokenVaultV2(
            POLYGON_DAI,
            referralCode,
            IPoolAddressesProvider(POLYGON_POOL_ADDRESSES_PROVIDER)
        );

        bytes memory data = abi.encodeWithSelector(ATokenVaultV2.initializeV2.selector);
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(vault)));
        vm.prank(PROXY_ADMIN);
        proxy.upgradeToAndCall(address(newImple), data);

        // Validate state
        assertEq(aliceBalanceBefore, vault.balanceOf(ALICE));
        assertEq(bobBalanceBefore, vault.balanceOf(BOB));
        assertEq(aliceRedeemBefore, vault.previewRedeem(aliceBalanceBefore));
        assertEq(bobRedeemBefore, vault.previewRedeem(bobBalanceBefore));
        assertEq(feesBefore, vault.getClaimableFees());
        assertEq(totalSupplyBefore, vault.totalSupply());
        assertEq(totalAssetsBefore, vault.totalAssets());
    }

    function testUpgradeRevertNonAdmin() public {
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(vault)));
        vm.expectRevert();
        proxy.upgradeTo(address(123));
    }
}
