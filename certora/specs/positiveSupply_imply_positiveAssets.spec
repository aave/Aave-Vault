import "methods_base.spec"

methods {
    totalAssets() returns uint256 envfree;
    Underlying.totalSupply() envfree;
    havoc_all() envfree;
    _SymbolicLendingPoolL1.getLiquidityIndex() envfree;

    rayMul(uint256 a,uint256 b) returns (uint256) => rayMul_g(a,b);
    rayDiv(uint256 a,uint256 b) returns (uint256) => rayDiv_g(a,b);
    
    havoc_all_dummy() => HAVOC_ALL;
    mulDiv(uint256 x, uint256 y, uint256 denominator, uint8 rounding) returns uint256 =>
        mulDiv4_g(x,y,denominator,rounding);
}

ghost mulDiv4_g(uint256 , uint256 , uint256, uint8) returns uint256 {
    axiom forall uint256 x. forall uint256 y. forall uint256 denominator. forall uint8 rounding.
        (
         ( (x==0 || y==0) => mulDiv4_g(x,y,denominator,rounding)==0)
         &&
         (mulDiv4_g(x,y,denominator,rounding)*denominator <= x*y)
         &&
         (y<=denominator => mulDiv4_g(x,y,denominator,rounding)<=x)
        );
}


ghost rayMul_g(uint256 , uint256) returns uint256 {
    axiom forall uint256 x. forall uint256 y.
        (
         ((x==0||y==0) => rayMul_g(x,y)==0)
         &&
         x <= rayMul_g(x,y) && rayMul_g(x,y) <= 2*x
        );
}
ghost rayDiv_g(uint256 , uint256) returns uint256 {
    axiom forall uint256 x. forall uint256 y.
        (
         x/2 <= rayDiv_g(x,y) && rayDiv_g(x,y) <= x
        );
}



/*
ghost rayMul_g(uint256 , uint256) returns uint256 {
    axiom forall uint256 x. forall uint256 y.rayMul_g(x,y)==x;
}
ghost rayDiv_g(uint256 , uint256) returns uint256 {
    axiom forall uint256 x. forall uint256 y. rayDiv_g(x,y)==x;
}
*/


// ******************************************************************************
// The following 3 invariants are proved in totalSupply_EQ_sumAllBal.spec
// ******************************************************************************
invariant inv_sumAllBalance_eq_totalSupply__underline()
    sumAllBalance_underline() == Underlying.totalSupply()

invariant inv_sumAllBalance_eq_totalSupply__atoken()
    sumAllBalance_atoken() == _AToken.scaledTotalSupply()

invariant inv_sumAllBalance_eq_totalSupply()
    sumAllBalance() == totalSupply()


// ******************************************************************************
// The following invariant is proved in lastVaultBalance_OK.spec.
// This is actually an under-approximation since getLastVaultBalance()
// might exceeds _AToken.balanceOf(currentContract) by a very small amount.
// ******************************************************************************
invariant lastVaultBalance_OK()
    getLastVaultBalance() <= _AToken.balanceOf(currentContract)



// ******************************************************************************
// The following invariant is proved in fee_LEQ_ATokenBal.spec and fee_LEQ_ATokenBal-RW.spec
// ******************************************************************************
invariant inv_fee_LEQ_ATokenBal()
//        to_uint256(                     );
    (getAccumulatedFees()+(_AToken.balanceOf(currentContract)-getLastVaultBalance()))
                                                       <= _AToken.balanceOf(currentContract)


function positiveSupply_imply_positiveAssets_DM(method f)
{
    env e;

    require e.msg.sender != currentContract;
    
    require getFee() <= SCALE();  // SCALE is 10^18
    require _AToken.balanceOf(currentContract) <= maxUint128();
    require totalSupply() <= maxUint128();
    require Underlying.totalSupply() <= maxUint128();
    require _AToken.scaledTotalSupply() <= maxUint128();
    requireInvariant inv_sumAllBalance_eq_totalSupply__underline(); 
    requireInvariant inv_sumAllBalance_eq_totalSupply__atoken(); 
    requireInvariant inv_sumAllBalance_eq_totalSupply();
    requireInvariant lastVaultBalance_OK();
    requireInvariant inv_fee_LEQ_ATokenBal();
    
    uint256 ind = _SymbolicLendingPoolL1.getLiquidityIndex();
    uint256 s_bal = _AToken.scaledBalanceOf(currentContract);

    // The following require means: (s_bal - ass/ind)*ind == s_bal*ind - ass
    require (forall uint256 ass.
             rayMul_g(to_uint256(s_bal-rayDiv_g(ass,ind)),ind) == to_uint256(rayMul_g(s_bal,ind)-ass)
            );

    //The following require means: (x/ind+z)*ind == x+z*ind 
    require (forall uint256 x. forall uint256 ind. forall uint256 z.
             rayMul_g(to_uint256(rayDiv_g(x,ind)+z),ind) == to_uint256(x+rayMul_g(z,ind))
            );

    require(totalSupply() != 0 => totalAssets() != 0);

    uint256 totS=totalSupply();
    uint256 totA=totalAssets();
    require (forall uint256 assets. forall uint8 rnd.
             totA-assets == 0  =>  totS-mulDiv4_g(assets,totS,totA,rnd) == 0
            );

    
    if (f.selector == handleDeposit_wrapper(uint256,address,address, bool).selector) {
        uint256 assets; address receiver; address depositor; bool asAToken;
        require depositor != currentContract;
        handleDeposit_wrapper(e,assets,receiver,depositor,asAToken);
    }
    else if (f.selector == handleMint_wrapper(uint256,address,address, bool).selector) {
        uint256 shares; address receiver; address depositor; bool asAToken;
        require depositor != currentContract;
        handleMint_wrapper(e,shares,receiver,depositor,asAToken);
    }
    else {
        calldataarg args;
        f(e,args);
    }

    require _AToken.balanceOf(currentContract) <= maxUint128();
    assert(totalSupply() != 0 => totalAssets() != 0);
}

rule positiveSupply_imply_positiveAssets_all_deposit(method f) filtered {
    f -> f.selector == handleDeposit_wrapper(uint256,address,address,bool).selector
}  {
    positiveSupply_imply_positiveAssets_DM(f);
}

rule positiveSupply_imply_positiveAssets_all_mint(method f) filtered {
    f -> f.selector == handleMint_wrapper(uint256,address,address,bool).selector
}  {
    positiveSupply_imply_positiveAssets_DM(f);
}


rule positiveSupply_imply_positiveAssets_other(method f) filtered {f ->
        f.selector != initialize(address,uint256,string,string,uint256).selector &&
        !harnessOnlyMethods(f) &&
        !f.isView &&
        !is_deposit_method(f) &&
        !is_mint_method(f) &&
        !is_withdraw_method(f) &&
        !is_redeem_method(f) 
        }
{
    positiveSupply_imply_positiveAssets_DM(f);
}


rule positiveSupply_imply_positiveAssets_specific_DM(method f)
{
    positiveSupply_imply_positiveAssets_DM(f);
}




function positiveSupply_imply_positiveAssets_RW(method f)
{
    env e;

    require e.msg.sender != currentContract;
    
    require getFee() <= SCALE();  // SCALE is 10^18
    require _AToken.balanceOf(currentContract) <= maxUint128();
    require totalSupply() <= maxUint128();
    require Underlying.totalSupply() <= maxUint128();
    require _AToken.scaledTotalSupply() <= maxUint128();
    requireInvariant inv_sumAllBalance_eq_totalSupply__underline(); 
    requireInvariant inv_sumAllBalance_eq_totalSupply__atoken(); 
    requireInvariant inv_sumAllBalance_eq_totalSupply();
    requireInvariant lastVaultBalance_OK();
    requireInvariant inv_fee_LEQ_ATokenBal();
    
    uint256 ind = _SymbolicLendingPoolL1.getLiquidityIndex();
    uint256 s_bal = _AToken.scaledBalanceOf(currentContract);

    // The following require means: (s_bal - ass/ind)*ind == s_bal*ind - ass
    require (forall uint256 ass.
             rayMul_g(to_uint256(s_bal-rayDiv_g(ass,ind)),ind) == to_uint256(rayMul_g(s_bal,ind)-ass)
            );

    require(totalSupply() != 0 => totalAssets() != 0);

    uint256 totS=totalSupply();
    uint256 totA=totalAssets();
    
    require (forall uint256 assets. forall uint8 rnd.
             totA-assets == 0  =>  totS-mulDiv4_g(assets,totS,totA,rnd) == 0
            );

    calldataarg args;
    f(e,args);

    assert(totalSupply() != 0 => totalAssets() != 0);
}



rule positiveSupply_imply_positiveAssets_all_withdraw(method f) filtered {
    f -> f.selector == handleWithdraw_wrapper(uint256,address,address,address,bool).selector
}  {
    positiveSupply_imply_positiveAssets_RW(f);
}

rule positiveSupply_imply_positiveAssets_all_redeem(method f) filtered {
    f -> f.selector == handleRedeem_wrapper(uint256,address,address,address,bool).selector
}  {
    positiveSupply_imply_positiveAssets_RW(f);
}


rule positiveSupply_imply_positiveAssets_specific_RW(method f)
{
    positiveSupply_imply_positiveAssets_RW(f);
}
