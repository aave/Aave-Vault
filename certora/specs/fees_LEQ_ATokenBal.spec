import "methods_base.spec";


methods {
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


function max_possible_fees() returns mathint {
    return getAccumulatedFees() + (_AToken.balanceOf(currentContract)-getLastVaultBalance());
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
// ******************************************************************************
invariant lastVaultBalance_OK()
  getLastVaultBalance() <= _AToken.balanceOf(currentContract)
  filtered {f -> f.contract==currentContract}


    
// ******************************************************************************
// Proving the solvency rule:
//           getClaimableFees() <= ATOKEN.balanceOf(theVault).
// We do it by proving the stronger invariant:
//           max_possible_fees() <= _AToken.balanceOf(currentContract)
// 
// Status: In CVL1: pass for all methods.
//         In CVL2: timedout !
//
// Note: We require that the totalSupply of currentContract, AToken, Underlying to be
//       less than maxUint128() to avoid failures due to overflows.
// ******************************************************************************


// ******************************************************************************
// In the following function and the next rule we prove the invariant for all methods exept:
// withraw*\redeem*\withdrawFees.
// ******************************************************************************
function getCLMFees_LEQ_ATokenBAL_1(method f) {
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
    
    uint256 index = _SymbolicLendingPoolL1.getLiquidityIndex();
    uint256 s_bal = _AToken.scaledBalanceOf(currentContract);


    // The following require means: (s_bal - ass/index)*index == s_bal*index - ass
    require (forall mathint ass.
             to_mathint(rayMul_MI(s_bal-rayDiv_MI(ass,index),index)) == rayMul_MI(s_bal,index)-ass
            );

    // The following require means: (x/ind+z)*ind == x+z*ind 
    require (forall mathint x. forall mathint ind. forall mathint z.
             to_mathint(rayMul_MI(rayDiv_MI(x,ind)+z,ind)) == x+rayMul_MI(z,ind)
            );
    
    require(max_possible_fees() <= to_mathint(_AToken.balanceOf(currentContract)));

    if (f.selector == sig:depositATokensWithSig(uint256,address,address,
                                                IATokenVault.EIP712Signature).selector) {
        uint256 assets; address receiver; address depositor;
        IATokenVault.EIP712Signature sigg;
        
        require depositor != currentContract;
        depositATokensWithSig(e,assets,receiver,depositor,sigg);
    }
    else if (f.selector == sig:mintWithATokensWithSig(uint256,address,address,
                                                      IATokenVault.EIP712Signature).selector) {
        uint256 shares; address receiver; address depositor;
        IATokenVault.EIP712Signature sigg;
        
        require depositor != currentContract;
        mintWithATokensWithSig(e, shares, receiver, depositor, sigg);
    }
    else {
        calldataarg args;
        f(e,args);
    }

    require _AToken.balanceOf(currentContract) <= assert_uint256(maxUint128());
    require totalSupply() <= assert_uint256(maxUint128());

    assert(max_possible_fees() <= to_mathint(_AToken.balanceOf(currentContract)));
}

rule getCLMFees_LEQ_ATokenBAL_DM_other(method f) filtered {f ->
    !harnessOnlyMethods(f) &&
    !f.isView &&
    !is_withdraw_method(f) &&
    !is_redeem_method(f) &&
    f.selector != sig:withdrawFees(address,uint256).selector
}
{
    getCLMFees_LEQ_ATokenBAL_1(f);
}




// ******************************************************************************
// In the following function and the next rule we prove the invariant for the methods:
// withraw*\redeem*\withdrawFees.
// ******************************************************************************
function getCLMFees_LEQ_ATokenBAL_2(method f) {
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
    
    uint256 ind = _SymbolicLendingPoolL1.getLiquidityIndex();
    uint256 s_bal = _AToken.scaledBalanceOf(currentContract);


    // The following require means: (s_bal - ass/ind)*ind == s_bal*ind - ass
    require (forall mathint ass.
             to_mathint(rayMul_MI(s_bal-rayDiv_MI(ass,ind),ind)) == rayMul_MI(s_bal,ind)-ass
            );

    require(max_possible_fees() <= to_mathint(_AToken.balanceOf(currentContract)));
    
    calldataarg args;
    f(e,args);

    assert(max_possible_fees() <= to_mathint(_AToken.balanceOf(currentContract)));
}

rule getCLMFees_LEQ_ATokenBAL_RW(method f) filtered {f ->
        !harnessOnlyMethods(f) &&
        !f.isView &&
        (is_withdraw_method(f) || is_redeem_method(f) ||
         f.selector == sig:withdrawFees(address,uint256).selector
        )
}
{
    getCLMFees_LEQ_ATokenBAL_2(f);
}
