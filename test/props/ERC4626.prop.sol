// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IERC4626 is IERC20 {
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    function asset() external view returns (address assetTokenAddress);

    function totalAssets() external view returns (uint256 totalManagedAssets);

    function convertToShares(uint256 assets) external view returns (uint256 shares);

    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    function maxMint(address receiver) external view returns (uint256 maxShares);

    function previewMint(uint256 shares) external view returns (uint256 assets);

    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    function maxRedeem(address owner) external view returns (uint256 maxShares);

    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);
}

abstract contract ERC4626Prop is Test {
    uint256 __delta__;

    address __underlying__;
    address __vault__;

    //
    // asset
    //

    // asset
    // "MUST NOT revert."
    function prop_asset(address caller) public {
        vm.prank(caller);
        IERC4626(__vault__).asset();
    }

    // totalAssets
    // "MUST NOT revert."
    function prop_totalAssets(address caller) public {
        vm.prank(caller);
        IERC4626(__vault__).totalAssets();
    }

    //
    // convert
    //

    // convertToShares
    // "MUST NOT show any variations depending on the caller."
    function prop_convertToShares(
        address caller1,
        address caller2,
        uint256 amount
    ) public {
        vm.prank(caller1);
        uint256 res1 = vault_convertToShares(amount); // "MAY revert due to integer overflow caused by an unreasonably large input."
        vm.prank(caller2);
        uint256 res2 = vault_convertToShares(amount); // "MAY revert due to integer overflow caused by an unreasonably large input."
        assertEq(res1, res2);
    }

    // convertToAssets
    // "MUST NOT show any variations depending on the caller."
    function prop_convertToAssets(
        address caller1,
        address caller2,
        uint256 amount
    ) public {
        vm.prank(caller1);
        uint256 res1 = vault_convertToAssets(amount); // "MAY revert due to integer overflow caused by an unreasonably large input."
        vm.prank(caller2);
        uint256 res2 = vault_convertToAssets(amount); // "MAY revert due to integer overflow caused by an unreasonably large input."
        assertEq(res1, res2);
    }

    //
    // deposit
    //

    // maxDeposit
    // "MUST NOT revert."
    function prop_maxDeposit(address caller, address receiver) public {
        vm.prank(caller);
        IERC4626(__vault__).maxDeposit(receiver);
    }

    // previewDeposit
    // "MUST return as close to and no more than the exact amount of Vault
    // shares that would be minted in a deposit call in the same transaction.
    // I.e. deposit should return the same or more shares as previewDeposit if
    // called in the same transaction."
    function prop_previewDeposit(
        address caller,
        address receiver,
        address other,
        uint256 assets
    ) public {
        vm.prank(other);
        uint256 sharesPreview = vault_previewDeposit(assets); // "MAY revert due to other conditions that would also cause deposit to revert."
        vm.prank(caller);
        uint256 sharesActual = vault_deposit(assets, receiver);
        assertApproxGeAbs(sharesActual, sharesPreview, __delta__);
    }

    // deposit
    function prop_deposit(
        address caller,
        address receiver,
        uint256 assets
    ) public {
        uint256 oldCallerAsset = IERC20(__underlying__).balanceOf(caller);
        uint256 oldReceiverShare = IERC20(__vault__).balanceOf(receiver);
        uint256 oldAllowance = IERC20(__underlying__).allowance(caller, __vault__);

        vm.prank(caller);
        uint256 shares = vault_deposit(assets, receiver);

        uint256 newCallerAsset = IERC20(__underlying__).balanceOf(caller);
        uint256 newReceiverShare = IERC20(__vault__).balanceOf(receiver);
        uint256 newAllowance = IERC20(__underlying__).allowance(caller, __vault__);

        assertApproxEqAbs(newCallerAsset, oldCallerAsset - assets, __delta__, "asset"); // NOTE: this may fail if the caller is a contract in which the asset is stored
        assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, __delta__, "share");
        if (oldAllowance != type(uint256).max) assertApproxEqAbs(newAllowance, oldAllowance - assets, __delta__, "allowance");
    }

    //
    // mint
    //

    // maxMint
    // "MUST NOT revert."
    function prop_maxMint(address caller, address receiver) public {
        vm.prank(caller);
        IERC4626(__vault__).maxMint(receiver);
    }

    // previewMint
    // "MUST return as close to and no fewer than the exact amount of assets
    // that would be deposited in a mint call in the same transaction. I.e. mint
    // should return the same or fewer assets as previewMint if called in the
    // same transaction."
    function prop_previewMint(
        address caller,
        address receiver,
        address other,
        uint256 shares
    ) public {
        vm.prank(other);
        uint256 assetsPreview = vault_previewMint(shares);
        vm.prank(caller);
        uint256 assetsActual = vault_mint(shares, receiver);
        assertApproxLeAbs(assetsActual, assetsPreview, __delta__);
    }

    // mint
    function prop_mint(
        address caller,
        address receiver,
        uint256 shares
    ) public {
        uint256 oldCallerAsset = IERC20(__underlying__).balanceOf(caller);
        uint256 oldReceiverShare = IERC20(__vault__).balanceOf(receiver);
        uint256 oldAllowance = IERC20(__underlying__).allowance(caller, __vault__);

        vm.prank(caller);
        uint256 assets = vault_mint(shares, receiver);

        uint256 newCallerAsset = IERC20(__underlying__).balanceOf(caller);
        uint256 newReceiverShare = IERC20(__vault__).balanceOf(receiver);
        uint256 newAllowance = IERC20(__underlying__).allowance(caller, __vault__);

        assertApproxEqAbs(newCallerAsset, oldCallerAsset - assets, __delta__, "asset"); // NOTE: this may fail if the caller is a contract in which the asset is stored
        assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, __delta__, "share");
        if (oldAllowance != type(uint256).max) assertApproxEqAbs(newAllowance, oldAllowance - assets, __delta__, "allowance");
    }

    //
    // withdraw
    //

    // maxWithdraw
    // "MUST NOT revert."
    // NOTE: some implementations failed due to arithmetic overflow
    function prop_maxWithdraw(address caller, address owner) public {
        vm.prank(caller);
        IERC4626(__vault__).maxWithdraw(owner);
    }

    // previewWithdraw
    // "MUST return as close to and no fewer than the exact amount of Vault
    // shares that would be burned in a withdraw call in the same transaction.
    // I.e. withdraw should return the same or fewer shares as previewWithdraw
    // if called in the same transaction."
    function prop_previewWithdraw(
        address caller,
        address receiver,
        address owner,
        address other,
        uint256 amount
    ) public {
        vm.prank(other);
        uint256 preview = vault_previewWithdraw(amount);
        vm.prank(caller);
        uint256 actual = vault_withdraw(amount, receiver, owner);
        assertApproxLeAbs(actual, preview, __delta__);
    }

    // withdraw
    function prop_withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets
    ) public {
        uint256 oldReceiverAsset = IERC20(__underlying__).balanceOf(receiver);
        uint256 oldOwnerShare = IERC20(__vault__).balanceOf(owner);
        uint256 oldAllowance = IERC20(__vault__).allowance(owner, caller);

        vm.prank(caller);
        uint256 shares = vault_withdraw(assets, receiver, owner);

        uint256 newReceiverAsset = IERC20(__underlying__).balanceOf(receiver);
        uint256 newOwnerShare = IERC20(__vault__).balanceOf(owner);
        uint256 newAllowance = IERC20(__vault__).allowance(owner, caller);

        assertApproxEqAbs(newOwnerShare, oldOwnerShare - shares, __delta__, "share");
        assertApproxEqAbs(newReceiverAsset, oldReceiverAsset + assets, __delta__, "asset"); // NOTE: this may fail if the receiver is a contract in which the asset is stored
        if (caller != owner && oldAllowance != type(uint256).max)
            assertApproxEqAbs(newAllowance, oldAllowance - shares, __delta__, "allowance");

        assertTrue(caller == owner || oldAllowance != 0 || (shares == 0 && assets == 0), "access control");
    }

    //
    // redeem
    //

    // maxRedeem
    // "MUST NOT revert."
    function prop_maxRedeem(address caller, address owner) public {
        vm.prank(caller);
        IERC4626(__vault__).maxRedeem(owner);
    }

    // previewRedeem
    // "MUST return as close to and no more than the exact amount of assets that
    // would be withdrawn in a redeem call in the same transaction. I.e. redeem
    // should return the same or more assets as previewRedeem if called in the
    // same transaction."
    function prop_previewRedeem(
        address caller,
        address receiver,
        address owner,
        address other,
        uint256 amount
    ) public {
        vm.prank(other);
        uint256 preview = vault_previewRedeem(amount);
        vm.prank(caller);
        uint256 actual = vault_redeem(amount, receiver, owner);
        assertApproxGeAbs(actual, preview, __delta__);
    }

    // redeem
    function prop_redeem(
        address caller,
        address receiver,
        address owner,
        uint256 shares
    ) public {
        uint256 oldReceiverAsset = IERC20(__underlying__).balanceOf(receiver);
        uint256 oldOwnerShare = IERC20(__vault__).balanceOf(owner);
        uint256 oldAllowance = IERC20(__vault__).allowance(owner, caller);

        vm.prank(caller);
        uint256 assets = vault_redeem(shares, receiver, owner);

        uint256 newReceiverAsset = IERC20(__underlying__).balanceOf(receiver);
        uint256 newOwnerShare = IERC20(__vault__).balanceOf(owner);
        uint256 newAllowance = IERC20(__vault__).allowance(owner, caller);

        assertApproxEqAbs(newOwnerShare, oldOwnerShare - shares, __delta__, "share");
        assertApproxEqAbs(newReceiverAsset, oldReceiverAsset + assets, __delta__, "asset"); // NOTE: this may fail if the receiver is a contract in which the asset is stored
        if (caller != owner && oldAllowance != type(uint256).max)
            assertApproxEqAbs(newAllowance, oldAllowance - shares, __delta__, "allowance");

        assertTrue(caller == owner || oldAllowance != 0 || (shares == 0 && assets == 0), "access control");
    }

    //
    // round trip properties
    //

    // redeem(deposit(a)) <= a
    function prop_RT_deposit_redeem(address caller, uint256 assets) public {
        vm.prank(caller);
        uint256 shares = vault_deposit(assets, caller);
        vm.prank(caller);
        uint256 assets2 = vault_redeem(shares, caller, caller);
        assertApproxLeAbs(assets2, assets, __delta__);
    }

    // s = deposit(a)
    // s' = withdraw(a)
    // s' >= s
    function prop_RT_deposit_withdraw(address caller, uint256 assets) public {
        vm.prank(caller);
        uint256 shares1 = vault_deposit(assets, caller);
        vm.prank(caller);
        uint256 shares2 = vault_withdraw(assets, caller, caller);
        assertApproxGeAbs(shares2, shares1, __delta__);
    }

    // deposit(redeem(s)) <= s
    function prop_RT_redeem_deposit(address caller, uint256 shares) public {
        vm.prank(caller);
        uint256 assets = vault_redeem(shares, caller, caller);
        vm.prank(caller);
        uint256 shares2 = vault_deposit(assets, caller);
        assertApproxLeAbs(shares2, shares, __delta__);
    }

    // a = redeem(s)
    // a' = mint(s)
    // a' >= a
    function prop_RT_redeem_mint(address caller, uint256 shares) public {
        vm.prank(caller);
        uint256 assets1 = vault_redeem(shares, caller, caller);
        vm.prank(caller);
        uint256 assets2 = vault_mint(shares, caller);
        assertApproxGeAbs(assets2, assets1, __delta__);
    }

    // withdraw(mint(s)) >= s
    function prop_RT_mint_withdraw(address caller, uint256 shares) public {
        vm.prank(caller);
        uint256 assets = vault_mint(shares, caller);
        vm.prank(caller);
        uint256 shares2 = vault_withdraw(assets, caller, caller);
        assertApproxGeAbs(shares2, shares, __delta__);
    }

    // a = mint(s)
    // a' = redeem(s)
    // a' <= a
    function prop_RT_mint_redeem(address caller, uint256 shares) public {
        vm.prank(caller);
        uint256 assets1 = vault_mint(shares, caller);
        vm.prank(caller);
        uint256 assets2 = vault_redeem(shares, caller, caller);
        assertApproxLeAbs(assets2, assets1, __delta__);
    }

    // mint(withdraw(a)) >= a
    function prop_RT_withdraw_mint(address caller, uint256 assets) public {
        vm.prank(caller);
        uint256 shares = vault_withdraw(assets, caller, caller);
        vm.prank(caller);
        uint256 assets2 = vault_mint(shares, caller);
        assertApproxGeAbs(assets2, assets, __delta__);
    }

    // s = withdraw(a)
    // s' = deposit(a)
    // s' <= s
    function prop_RT_withdraw_deposit(address caller, uint256 assets) public {
        vm.prank(caller);
        uint256 shares1 = vault_withdraw(assets, caller, caller);
        vm.prank(caller);
        uint256 shares2 = vault_deposit(assets, caller);
        assertApproxLeAbs(shares2, shares1, __delta__);
    }

    //
    // utils
    //

    function vault_convertToShares(uint256 assets) internal returns (uint256) {
        return _call_vault(abi.encodeWithSelector(IERC4626.convertToShares.selector, assets));
    }

    function vault_convertToAssets(uint256 shares) internal returns (uint256) {
        return _call_vault(abi.encodeWithSelector(IERC4626.convertToAssets.selector, shares));
    }

    function vault_previewDeposit(uint256 assets) internal returns (uint256) {
        return _call_vault(abi.encodeWithSelector(IERC4626.previewDeposit.selector, assets));
    }

    function vault_previewMint(uint256 shares) internal returns (uint256) {
        return _call_vault(abi.encodeWithSelector(IERC4626.previewMint.selector, shares));
    }

    function vault_previewWithdraw(uint256 assets) internal returns (uint256) {
        return _call_vault(abi.encodeWithSelector(IERC4626.previewWithdraw.selector, assets));
    }

    function vault_previewRedeem(uint256 shares) internal returns (uint256) {
        return _call_vault(abi.encodeWithSelector(IERC4626.previewRedeem.selector, shares));
    }

    function vault_deposit(uint256 assets, address receiver) internal returns (uint256) {
        return _call_vault(abi.encodeWithSelector(IERC4626.deposit.selector, assets, receiver));
    }

    function vault_mint(uint256 shares, address receiver) internal returns (uint256) {
        return _call_vault(abi.encodeWithSelector(IERC4626.mint.selector, shares, receiver));
    }

    function vault_withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) internal returns (uint256) {
        return _call_vault(abi.encodeWithSelector(IERC4626.withdraw.selector, assets, receiver, owner));
    }

    function vault_redeem(
        uint256 shares,
        address receiver,
        address owner
    ) internal returns (uint256) {
        return _call_vault(abi.encodeWithSelector(IERC4626.redeem.selector, shares, receiver, owner));
    }

    function _call_vault(bytes memory data) internal returns (uint256) {
        (bool success, bytes memory retdata) = __vault__.call(data);
        if (success) return abi.decode(retdata, (uint256));
        vm.assume(false); // if reverted, discard the current fuzz inputs, and let the fuzzer to start a new fuzz run
        return 0; // silence warning
    }

    function assertApproxGeAbs(
        uint256 a,
        uint256 b,
        uint256 maxDelta
    ) internal {
        if (!(a >= b)) {
            uint256 dt = b - a;
            if (dt > maxDelta) {
                emit log("Error: a >=~ b not satisfied [uint]");
                emit log_named_uint("   Value a", a);
                emit log_named_uint("   Value b", b);
                emit log_named_uint(" Max Delta", maxDelta);
                emit log_named_uint("     Delta", dt);
                fail();
            }
        }
    }

    function assertApproxLeAbs(
        uint256 a,
        uint256 b,
        uint256 maxDelta
    ) internal {
        if (!(a <= b)) {
            uint256 dt = a - b;
            if (dt > maxDelta) {
                emit log("Error: a <=~ b not satisfied [uint]");
                emit log_named_uint("   Value a", a);
                emit log_named_uint("   Value b", b);
                emit log_named_uint(" Max Delta", maxDelta);
                emit log_named_uint("     Delta", dt);
                fail();
            }
        }
    }
}
