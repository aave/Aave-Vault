// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ATokenVault} from "../munged/src/ATokenVault.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {DummyContract} from "./DummyContract.sol";

import {SafeERC20Upgradeable} from "@openzeppelin-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin-upgradeable/interfaces/IERC20Upgradeable.sol";

import {MathUpgradeable} from "@openzeppelin-upgradeable/utils/math/MathUpgradeable.sol";
import {WadRayMath} from "@aave-v3-core/protocol/libraries/math/WadRayMath.sol";



/**
 * @title ATokenVault
 * @author Aave Protocol
 * @notice An ERC-4626 vault for Aave V3, with support to add a fee on yield earned.
 */
contract ATokenVaultHarness is ATokenVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;
    DummyContract DUMMY;
    
    constructor(address underlying, uint16 referralCode, IPoolAddressesProvider poolAddressesProvider) ATokenVault(underlying, referralCode, poolAddressesProvider) {
    }
    
    function havoc_all() public {
        DUMMY.havoc_all_dummy();
    }
    
    function accrueYield() external {
        _accrueYield();
    }
    
    function getAccumulatedFees() external returns(uint128) {
        return _s.accumulatedFees;
    }

    function maxAssetsWithdrawableFromAave() external view returns (uint256) {
        return _maxAssetsWithdrawableFromAave();
    }

    function maxAssetsWithdrawableFromAaveWrapper() external returns (uint256){
        return _maxAssetsWithdrawableFromAave();
    }

    function mulDiv__(uint256 x, uint256 y, uint256 deno, uint8 rounding) external returns(uint256 result) {
        if (rounding==0)
            result = x.mulDiv(y,deno,MathUpgradeable.Rounding.Down);
        else
            result = x.mulDiv(y,deno,MathUpgradeable.Rounding.Up);
    }

    function rayMul__(uint256 a, uint256 b) external returns (uint256) {
        return WadRayMath.rayMul(a,b);
    }

    function rayDiv__(uint256 a, uint256 b) external returns (uint256) {
        return WadRayMath.rayDiv(a,b);
    }

    function handleDeposit_wrapper(uint256 assets, address receiver, address depositor, bool asAToken)
        external returns (uint256) {
        return _handleDeposit(assets,receiver,depositor,asAToken);
    }
    function handleMint_wrapper(uint256 shares, address receiver, address depositor, bool asAToken)
        external returns (uint256) {
        return _handleMint(shares,receiver,depositor,asAToken);
    }
    function handleWithdraw_wrapper(uint256 assets, address receiver, address owner, address allowanceTarget, bool asAToken)
        external returns (uint256) {
        return _handleWithdraw(assets,receiver,owner,allowanceTarget,asAToken);
    }
    function handleRedeem_wrapper(uint256 shares, address receiver, address owner, address allowanceTarget, bool asAToken)
        external returns (uint256) {
        return _handleRedeem(shares,receiver,owner,allowanceTarget,asAToken);
    }


        
}
