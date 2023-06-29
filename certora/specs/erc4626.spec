import "methods_base.spec"

//using DummyContract as _DummyContract

methods {
    rayMul(uint256 a,uint256 b) returns (uint256) => rayMul_g(a,b);
    rayDiv(uint256 a,uint256 b) returns (uint256) => rayDiv_g(a,b);
    havoc_all() envfree;
    
    havoc_all_dummy() => HAVOC_ALL;
    mulDiv(uint256 x, uint256 y, uint256 denominator) returns uint256 => mulDiv3_g(x,y,denominator);
    //mulDiv(uint256 x, uint256 y, uint256 denominator, uint8 rounding) returns uint256 => mulDiv4_g(x,y,denominator,rounding) ;
}

/*
function mulDiv4_g(uint256 x, uint256 y, uint256 denominator, uint8 rounding) returns uint256 {
    uint256 result = mulDiv3_g(x, y, denominator);

    require (denominator != 0);
    mathint mulmod = (x*y) % denominator;
    if (rounding == 1 && mulmod > 0) {
        result = result + 1;
    }
    return result;
    }*/

ghost mulDiv3_g(uint256 , uint256 , uint256) returns uint256 {
    axiom 1==1;
}
ghost rayMul_g(uint256 , uint256) returns uint256 {
    axiom 1==1;
}
ghost rayDiv_g(uint256 , uint256) returns uint256 {
    axiom 1==1;
}


// ****************************************************************
// By EIP4626, the following functions must not revert
// ****************************************************************
function f_must_NOT_revert(method f) returns bool {
    return 
        f.selector == asset().selector ||
        f.selector == totalAssets().selector ||
        f.selector == maxDeposit(address).selector ||
        f.selector == maxMint(address).selector ||
        f.selector == maxWithdraw(address).selector ||
        f.selector == maxRedeem(address).selector
    ;
}


// ****************************************************************
// By EIP4626, the following functions:
// MUST NOT revert unless due to integer overflow caused by an unreasonably large input.
// ****************************************************************
function f_must_NOT_revert_unless_large_input(method f) returns bool {
    return
        f.selector == convertToShares(uint256).selector ||
        f.selector == convertToAssets(uint256).selector
        ;
}


// ****************************************************************
// By EIP4626: the functions: asset, totalAssets, maxDeposit, maxMint, maxWithdraw, maxRedeem
// must not revert.
//
// STATUS: fail
// - asset() indeed does not revert.
// - All the other function may revert due to arithmetical calculations.
// ****************************************************************
rule must_not_revert(method f) {
    env e;
    calldataarg args;

    require f_must_NOT_revert(f);
    require e.msg.value == 0;

    f@withrevert(e, args); 
    bool reverted = lastReverted;

    assert !reverted, "A function that should not revert has reverted";
}


// ****************************************************************
// By EIP4626, the function convertToShares(uint256) should comply with:
// MUST NOT revert unless due to integer overflow caused by an unreasonably large input.

// STATUS: fail
// there are arithmetical calculations that may revert in the function totalAssets()
// ****************************************************************
rule must_not_revert_unless_large_input__convertToShares() {
    env e;
    require e.msg.value == 0;
    uint256 assets;
    require (assets <= maxUint128());
    
    convertToShares@withrevert(e, assets);
    bool reverted = lastReverted;

    assert !reverted, "Conversion to shares reverted";
}


// ****************************************************************
// By EIP4626, the function convertToAssets(uint256) should comply with:
// MUST NOT revert unless due to integer overflow caused by an unreasonably large input.

// STATUS: fail
// there are arithmetical calculations that may revert in the function totalAssets()
// ****************************************************************
rule must_not_revert_unless_large_input__convertToAssets() {
    env e;
    require e.msg.value == 0;
    uint256 shares;
    require (shares <= maxUint128());
    
    convertToAssets@withrevert(e, shares);
    bool reverted = lastReverted;

    assert !reverted, "Conversion to shares reverted";
}




// ****************************
// *       previewDeposit     *
// ****************************

// Rule to check the following for the previewDeposit function:
// 1. MUST return as close to and no more than the exact amount of Vault shares that would 
//    be minted in a deposit call in the same transaction.
// I.e. deposit should return the same or more shares as previewDeposit if called in the
// same transaction.

// STATUS: pass
// The amount returned by previewDeposit is exactly equal to that returned by the deposit function.

rule previewDeposit_amount_check() {
    env e1;
    env e2;
    uint256 assets;
    address receiver;   
    uint256 previewShares;
    uint256 shares;

    require e1.block.timestamp <= e2.block.timestamp;
    require e2.block.timestamp <= 0xffffff;

    require _AToken.balanceOf(currentContract) <= maxUint128();
    require getAccumulatedFees() <= maxUint128();
    require getLastVaultBalance() <= maxUint128();
    require totalSupply() <= maxUint128();
    
    require(getFee() <= SCALE());  // SCALE is 10^18

    
    previewShares = previewDeposit(e1, assets);
    shares = deposit(e2, assets, receiver);

    assert previewShares == shares, "preview shares should be equal to actual shares";
}



/*
  The EIP4626 spec requires that the previewDeposit function must not account for maxDeposit 
  limit or the allowance of asset tokens.
  The following rule checks that the value returned by the previewDeposit depends only on
  totalSupply() and totalAssets().

  STATUS: fail
  The value depends on the value returned by _maxAssetsSuppliableToAave().
*/

rule previewDeposit_has_NO_threshold(env e1, env e2) {
    require e1.block.timestamp <= e2.block.timestamp;
    require e2.block.timestamp <= 0xffffff;

    uint256 assets;

    uint256 total_supply_1 = totalSupply();
    uint256 total_assets_1 = totalAssets(e1);   
    uint256 previewShares1 = previewDeposit(e1, assets);

    havoc_all();
    require (total_supply_1 == totalSupply());
    require (total_assets_1 == totalAssets(e2));
    uint256 previewShares2 = previewDeposit(e2, assets);

    assert (previewShares1 == previewShares2);
}


// ****************************
// *        previewMint       
// **************************

// Rule to check the following for the previewMint function:
// 1. MUST return as close to and no more than the exact amount of Vault shares that would 
//    be minted in a deposit call in the same transaction.
// I.e. deposit should return the same or more shares as previewDeposit if called in the
// same transaction.

// STATUS: pass
// The amount returned by previewMint is exactly equal to that returned by the mint function.

rule previewMint_amount_check() {
    env e1;
    env e2;
    uint256 shares;
    address receiver;
    uint256 previewAssets;
    uint256 assets;

    require e1.block.timestamp <= e2.block.timestamp;
    require e2.block.timestamp <= 0xffffff;

    require _AToken.balanceOf(currentContract) <= maxUint128();
    require getAccumulatedFees() <= maxUint128();
    require getLastVaultBalance() <= maxUint128();
    require totalSupply() <= maxUint128();

    require(getFee() <= SCALE());  // SCALE is 10^18
        
    previewAssets = previewMint(e1,shares);
    require (shares <= convertToShares(e2,maxDeposit(receiver)) => convertToAssets(e2,shares) <= maxDeposit(receiver));
    assets = mint(e2, shares, receiver);
    assert previewAssets == assets || previewAssets == assets+1 || previewAssets+1 == assets, "preview should be equal to actual - mint";
}



/*
  The EIP4626 spec requires that the previewMint function must not account for mint limits 
  like those returned from maxMint and should always act as though the mint would be accepted, 
  regardless whether the user has approved the contract to transfer the specified amount of assets.
  The following rule checks that the value returned by the previewDeposit depends only on
  totalSupply() and totalAssets().

  STATUS: fail
  The value depends on the value returned by _maxAssetsSuppliableToAave().
*/

rule previewMint_has_NO_threshold(env e1, env e2) {
    require e1.block.timestamp <= e2.block.timestamp;
    require e2.block.timestamp <= 0xffffff;
    
    uint256 shares;

    uint256 total_supply_1 = totalSupply();
    uint256 total_assets_1 = totalAssets(e1);   
    uint256 preview_assets_1 = previewMint(e1, shares);

    havoc_all();
    require (total_supply_1 == totalSupply());
    require (total_assets_1 == totalAssets(e2));
    uint256 preview_assets_2 = previewMint(e2, shares);

    assert (preview_assets_1 == preview_assets_2);
}




// ********************************
// *        previewWithdraw       *
// ********************************

// rule to check the following for the previewWithdraw function:
// 1. MUST return as close to and no fewer than the exact amount of Vault shares that
//    would be burned in a withdraw call in the same transaction.
// I.e. withdraw should return the same or fewer shares as previewWithdraw if called in
// the same transaction.

// STATUS: pass
// The amount returned by previewWithdraw is exactly equal to that returned by the withdraw function.

rule previewWithdraw_amount_check(env e1, env e2) {
    require e1.block.timestamp <= e2.block.timestamp;
    require e2.block.timestamp <= 0xffffff;

    uint256 assets;
    address receiver;
    address owner;
    uint256 shares;
    uint256 previewShares;

    require _AToken.balanceOf(currentContract) <= maxUint128();
    require getAccumulatedFees() <= maxUint128();
    require getLastVaultBalance() <= maxUint128();
    require totalSupply() <= maxUint128();
    require(getFee() <= SCALE());  // SCALE is 10^18

    previewShares = previewWithdraw(e1, assets);
    shares = withdraw(e2, assets, receiver, owner);
    
    assert previewShares == shares,"preview should be equal to actual - withdraw";
}



/*
  The EIP4626 spec requires that the previewWithdraw function must not account for withdrawal 
  limits like those returned from maxWithdraw and should always act as though the withdrawal 
  would be accepted, regardless of whether or not the user has enough shares, etc. 
  The following rule checks that the value returned by the previewWithdraw depends only on
  totalSupply() and totalAssets().

  STATUS: fail
  The value depends on the status of the user.
*/

rule previewWithdraw_has_NO_threshold(env e1, env e2) {
    require e1.block.timestamp <= e2.block.timestamp;
    require e2.block.timestamp <= 0xffffff;

    uint256 assets;

    uint256 total_supply_1 = totalSupply();
    uint256 total_assets_1 = totalAssets(e1);   
    uint256 previewShares1 = previewWithdraw(e1, assets);

    havoc_all();
    require (total_supply_1 == totalSupply());
    require (total_assets_1 == totalAssets(e2));
    uint256 previewShares2 = previewWithdraw(e2, assets);

    assert (previewShares1 == previewShares2);
}







// *****************************
// *        previewRedeem      *
// *****************************

// rule to check the following for the previewRedeem function:
// 1. MUST return as CLOSE to and no more than the exact amount of assets that would be
//    withdrawn in a redeem call in the same transaction.
// I.e. redeem should return the same or more assets as previewRedeem if called in the
// same transaction.

// STATUS: pass
// The amount returned by previewRedeem is exactly equal to that returned by the redeem function.

rule previewRedeem_amount_check(env e1, env e2){
    uint256 shares;
    address receiver;
    address owner;
    uint256 previewAssets;
    uint256 assets;
    
    require e1.block.timestamp <= e2.block.timestamp;
    require e2.block.timestamp <= 0xffffff;

    require _AToken.balanceOf(currentContract) <= maxUint128();
    require getAccumulatedFees() <= maxUint128();
    require getLastVaultBalance() <= maxUint128();
    require totalSupply() <= maxUint128();
    require (getFee() <= SCALE());  // SCALE is 10^18

    previewAssets = previewRedeem(e1, shares);
    require (shares <= convertToShares(e2,maxAssetsWithdrawableFromAave()) =>
                     convertToAssets(e2,shares) <= maxAssetsWithdrawableFromAave());
    assets = redeem(e2, shares, receiver, owner);
    
    assert previewAssets == assets 
        || previewAssets + 1 == assets
        //        || previewAssets + 2 == assets        
        ,"preview should the same as the actual assets received";
}


/*
  The EIP4626 spec requires that the previewRedeem function must not account for redemption 
  limits like those returned by the maxRedeem function and should always act as though the 
  redemption would be accepted, regardless if the user has enough shares, etc.
  The following rule checks that the value returned by the previewRedeem depends only on
  totalSupply() and totalAssets().

  STATUS: fail
  The value depends on the status of the user.

*/

rule previewRedeem_has_NO_threshold(env e1, env e2) {
    require e1.block.timestamp <= e2.block.timestamp;
    require e2.block.timestamp <= 0xffffff;
    
    uint256 shares;

    uint256 total_supply_1 = totalSupply();
    uint256 total_assets_1 = totalAssets(e1);   
    uint256 preview_assets_1 = previewRedeem(e1, shares);

    havoc_all();
    require (total_supply_1 == totalSupply());
    require (total_assets_1 == totalAssets(e2));
    uint256 preview_assets_2 = previewRedeem(e2, shares);

    assert (preview_assets_1 == preview_assets_2);
}

