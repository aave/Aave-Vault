import "methods_base.spec";

methods {
    function totalAssets() external returns (uint256) envfree;
    //    function Underlying.totalSupply() external envfree;
    function havoc_all() external envfree;
    function SymbolicLendingPoolL1.getLiquidityIndex() external returns (uint256) envfree;

    function _.rayMul(uint256 a,uint256 b) internal => rayMul_MI(a,b) expect uint256 ALL;
    function _.rayDiv(uint256 a,uint256 b) internal => rayDiv_MI(a,b) expect uint256 ALL;
    
    function _.havoc_all_dummy() external => HAVOC_ALL;

    function _.mulDiv(uint256 x, uint256 y, uint256 denominator, MathUpgradeable.Rounding rounding) internal =>
        mulDiv4_g(x,y,denominator) expect uint256 ALL;
}

ghost mulDiv4_g(uint256 , uint256 , uint256) returns uint256 {
    axiom forall uint256 x. forall uint256 y. forall uint256 denominator.
        (
         ( (x==0 || y==0) => mulDiv4_g(x,y,denominator)==0)
         &&
         (mulDiv4_g(x,y,denominator)*denominator <= x*y)
         &&
         (y<=denominator => mulDiv4_g(x,y,denominator)<=x)
        );
}


ghost rayMul_MI(mathint , mathint) returns uint256 {
    axiom forall mathint x. forall mathint y.
        (
         ((x==0||y==0) => rayMul_MI(x,y)==0)
         &&
         x <= to_mathint(rayMul_MI(x,y)) && to_mathint(rayMul_MI(x,y)) <= 2*x
        );
}
ghost rayDiv_MI(mathint , mathint) returns uint256 {
    axiom forall mathint x. forall mathint y.
        (
         x/2 <= to_mathint(rayDiv_MI(x,y)) && to_mathint(rayDiv_MI(x,y)) <= x
        );
}



// ******************************************************************************
// The following 3 invariants are proved in totalSupply_EQ_sumAllBal.spec
// ******************************************************************************
invariant inv_sumAllBalance_eq_totalSupply__underline()
    sumAllBalance_underline() == to_mathint(Underlying.totalSupply());

invariant inv_sumAllBalance_eq_totalSupply__atoken()
    sumAllBalance_atoken() == to_mathint(_AToken.scaledTotalSupply());

invariant inv_sumAllBalance_eq_totalSupply()
    sumAllBalance() == to_mathint(totalSupply());


// ******************************************************************************
// The following invariant is proved in lastVaultBalance_OK.spec
// This is actually an under-approximation since getLastVaultBalance()
// might exceeds _AToken.balanceOf(currentContract) by a very small amount.
// ******************************************************************************
invariant lastVaultBalance_OK()
    getLastVaultBalance() <= _AToken.balanceOf(currentContract);


// ******************************************************************************
// The following invariant is proved in fee_LEQ_ATokenBal.spec and fee_LEQ_ATokenBal-RW.spec
// ******************************************************************************
invariant inv_fee_LEQ_ATokenBal()
//        to_uint256(                     );
    (getAccumulatedFees()+(_AToken.balanceOf(currentContract)-getLastVaultBalance()))
    <=
    to_mathint(_AToken.balanceOf(currentContract));



// ******************************************************************************
// Proving the solvency rule:
//           totalSupply() != 0 => totalAssets() != 0
// 
// Status: In CVL1: pass for all methods.
//         In CVL2: timedout !
//
// Note: We require that the totalSupply of currentContract, AToken, Underlying to be
//       less than maxUint128() to avoid failures due to overflows.
// ******************************************************************************


// ******************************************************************************
// In the following function and the next rules we prove the invariant for all methods exept:
// withraw*\redeem*.
// ******************************************************************************
function positiveSupply_imply_positiveAssets_DM(method f)
{
    env e;

    require e.msg.sender != currentContract;
    
    require getFee() <= SCALE();  // SCALE is 10^18
    require _AToken.balanceOf(currentContract) <= assert_uint256(maxUint128());
    require totalSupply() <= assert_uint256(maxUint128());
    require Underlying.totalSupply() <= assert_uint256(maxUint128());
    require _AToken.scaledTotalSupply() <= assert_uint256(maxUint128());
    requireInvariant inv_sumAllBalance_eq_totalSupply__underline(); 
    requireInvariant inv_sumAllBalance_eq_totalSupply__atoken(); 
    requireInvariant inv_sumAllBalance_eq_totalSupply();
    requireInvariant lastVaultBalance_OK();
    requireInvariant inv_fee_LEQ_ATokenBal();

    uint256 index = _SymbolicLendingPoolL1.getLiquidityIndex();
    uint256 s_bal = _AToken.scaledBalanceOf(currentContract);

    // The following require means: (s_bal - ass/index)*index == s_bal*index - ass
    require (forall mathint ass.
             to_mathint(rayMul_MI(s_bal-rayDiv_MI(ass,index),index)) == rayMul_MI(s_bal,index)-ass
            );

    
    //The following require means: (x/ind+z)*ind == x+z*ind 
    require (forall mathint x. forall mathint ind. forall mathint z.
             to_mathint(rayMul_MI(rayDiv_MI(x,ind)+z,ind)) == x+rayMul_MI(z,ind)
            );

    require(totalSupply() != 0 => totalAssets() != 0);

    uint256 totS=totalSupply();
    uint256 totA=totalAssets();   
    require (forall uint256 assets.
             totA-assets == 0  =>  totS-mulDiv4_g(assets,totS,totA) == 0
            );

    if (f.selector == sig:handleDeposit_wrapper(uint256,address,address, bool).selector) {
        uint256 assetss; address receiver; address depositor; bool asAToken;
        require depositor != currentContract;
        handleDeposit_wrapper(e,assetss,receiver,depositor,asAToken);
    }
    else if (f.selector == sig:handleMint_wrapper(uint256,address,address, bool).selector) {
        uint256 shares; address receiver; address depositor; bool asAToken;
        require depositor != currentContract;
        handleMint_wrapper(e,shares,receiver,depositor,asAToken);
    }
    else {
        calldataarg args;
        f(e,args);
    }

    require _AToken.balanceOf(currentContract) <= assert_uint256(maxUint128());
    assert(totalSupply() != 0 => totalAssets() != 0);
}


rule positiveSupply_imply_positiveAssets_all_deposit(method f) filtered {
    f -> f.selector == sig:handleDeposit_wrapper(uint256,address,address,bool).selector
}  {
    positiveSupply_imply_positiveAssets_DM(f);
}

rule positiveSupply_imply_positiveAssets_all_mint(method f) filtered {
    f -> f.selector == sig:handleMint_wrapper(uint256,address,address,bool).selector
}  {
    positiveSupply_imply_positiveAssets_DM(f);
}


rule positiveSupply_imply_positiveAssets_other(method f) filtered {f ->
    f.contract==currentContract &&
    f.selector != sig:initialize(address,uint256,string,string,uint256).selector &&
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



// ******************************************************************************
// In the following function and the next rules we prove the invariant for the methods:
// withraw*\redeem*.
// ******************************************************************************
function positiveSupply_imply_positiveAssets_RW(method f)
{
    env e;

    require e.msg.sender != currentContract;
    
    require getFee() <= SCALE();  // SCALE is 10^18
    require _AToken.balanceOf(currentContract) <= assert_uint256(maxUint128());
    require totalSupply() <= assert_uint256(maxUint128());
    require Underlying.totalSupply() <= assert_uint256(maxUint128());
    require _AToken.scaledTotalSupply() <= assert_uint256(maxUint128());
    requireInvariant inv_sumAllBalance_eq_totalSupply__underline(); 
    requireInvariant inv_sumAllBalance_eq_totalSupply__atoken(); 
    requireInvariant inv_sumAllBalance_eq_totalSupply();
    requireInvariant lastVaultBalance_OK();
    requireInvariant inv_fee_LEQ_ATokenBal();

    uint256 ind = _SymbolicLendingPoolL1.getLiquidityIndex();
    uint256 s_bal = _AToken.scaledBalanceOf(currentContract);

    // The following require means: (s_bal - ass/ind)*ind == s_bal*ind - ass
    require (forall mathint ass.
             to_mathint(rayMul_MI(s_bal-rayDiv_MI(ass,ind),ind)) == rayMul_MI(s_bal,ind)-ass
            );

    require(totalSupply() != 0 => totalAssets() != 0);

    uint256 totS=totalSupply();
    uint256 totA=totalAssets();   

    require (forall uint256 assets.
             totA-assets == 0  =>  totS-mulDiv4_g(assets,totS,totA) == 0
            );

    calldataarg args;
    f(e,args);

    assert(totalSupply() != 0 => totalAssets() != 0);
}


rule positiveSupply_imply_positiveAssets_all_withdraw(method f) filtered {
    f -> f.selector == sig:handleWithdraw_wrapper(uint256,address,address,address,bool).selector
}  {
    positiveSupply_imply_positiveAssets_RW(f);
}

rule positiveSupply_imply_positiveAssets_all_redeem(method f) filtered {
    f -> f.selector == sig:handleRedeem_wrapper(uint256,address,address,address,bool).selector
}  {
    positiveSupply_imply_positiveAssets_RW(f);
}

rule positiveSupply_imply_positiveAssets_specific_RW(method f)
{
    positiveSupply_imply_positiveAssets_RW(f);
}



