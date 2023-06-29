import "methods_base.spec"


methods {
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


function max_possible_fees() returns uint256 {
    return to_uint256(getAccumulatedFees()
                      +
                      (_AToken.balanceOf(currentContract)-getLastVaultBalance())
                     );
}





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
// The following invariant is proved in lastVaultBalance_OK.spec
// ******************************************************************************
invariant lastVaultBalance_OK()
    getLastVaultBalance() <= _AToken.balanceOf(currentContract)


    
// ******************************************************************************
// Proving the solvency rule:
//           getClaimableFees() <= ATOKEN.balanceOf(theVault).
// We do it by proving the stronger invariant:
//           max_possible_fees() <= _AToken.balanceOf(currentContract)
// 
// In this file we prove all method exept the following
// withraw*\redeem*\withdrawFees. (those methods are treated in fee_LEQ_ATokenBal-RW.spec
// Note: the reason for the seperation is that different methods require different summarizations.
//
// Status: pass for all methods that are checked in this file, but FAIL of the others.
//         See in fee_LEQ_ATokenBal-RW.spec
//
// Note: We require that the totalSupply of currentContract, AToken, Underlying to be
//       less than maxUint128() to avoid failures due to overflows.
// ******************************************************************************
    
function getCLMFees_LEQ_ATokenBAL_1(method f) {
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
    
    uint256 ind = _SymbolicLendingPoolL1.getLiquidityIndex();
    uint256 s_bal = _AToken.scaledBalanceOf(currentContract);


    // The following require means: (s_bal - ass/ind)*ind == s_bal*ind - ass
    require (forall uint256 ass.
             rayMul_g(to_uint256(s_bal-rayDiv_g(ass,ind)),ind) == to_uint256(rayMul_g(s_bal,ind)-ass)
            );

    // The following require means: (x/ind+z)*ind == x+z*ind 
    require (forall uint256 x. forall uint256 ind. forall uint256 z.
             rayMul_g(to_uint256(rayDiv_g(x,ind)+z),ind) == to_uint256(x+rayMul_g(z,ind))
            );
    
    require(max_possible_fees() <= _AToken.balanceOf(currentContract));

    if (f.selector == depositATokensWithSig(uint256,address,address,
                                            (uint8,bytes32,bytes32,uint256)).selector) {
        uint256 assets; address receiver; address depositor;
        _ATokenVaultHarness.EIP712Signature sig;
        
        require depositor != currentContract;
        depositATokensWithSig(e,assets,receiver,depositor,sig);
    }
    else if (f.selector == mintWithATokensWithSig(uint256,address,address,
                                             (uint8,bytes32,bytes32,uint256)).selector) {
        uint256 shares; address receiver; address depositor;
        _ATokenVaultHarness.EIP712Signature sig;
        
        require depositor != currentContract;
        mintWithATokensWithSig(e, shares, receiver, depositor, sig);
    }
    else {
        calldataarg args;
        f(e,args);
    }

    require _AToken.balanceOf(currentContract) <= maxUint128();
    require totalSupply() <= maxUint128();
    //    require Underlying.totalSupply() <= maxUint128();
    //require _AToken.scaledTotalSupply() <= maxUint128();

    assert(max_possible_fees() <= _AToken.balanceOf(currentContract));
}

rule getCLMFees_LEQ_ATokenBAL_DM_other(method f) filtered {f ->
    !harnessOnlyMethods(f) &&
    !f.isView &&
    !is_withdraw_method(f) &&
    !is_redeem_method(f) &&
    f.selector != withdrawFees(address,uint256).selector
}
{
    getCLMFees_LEQ_ATokenBAL_1(f);
}



function getCLMFees_LEQ_ATokenBAL_2(method f) {
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
    
    uint256 ind = _SymbolicLendingPoolL1.getLiquidityIndex();
    uint256 s_bal = _AToken.scaledBalanceOf(currentContract);

    
    // The following require means: (s_bal - ass/ind)*ind == s_bal*ind - ass
    require (forall uint256 ass.
             rayMul_g(to_uint256(s_bal-rayDiv_g(ass,ind)),ind) == to_uint256(rayMul_g(s_bal,ind)-ass)
            );

    // The following require means: (x/ind+z)*ind == x+z*ind 
    //require (forall uint256 x. forall uint256 ind. forall uint256 z.
    //         rayMul_g(to_uint256(rayDiv_g(x,ind)+z),ind) == to_uint256(x+rayMul_g(z,ind))
    //        );
    
    //require(_AToken.balanceOf(currentContract) < 1000);
    //require(getAccumulatedFees()*2 <= _AToken.balanceOf(currentContract));
    require(max_possible_fees() <= _AToken.balanceOf(currentContract));
    
    calldataarg args;
    f(e,args);

    assert(max_possible_fees() <= _AToken.balanceOf(currentContract));
}

rule getCLMFees_LEQ_ATokenBAL_RW(method f) filtered {f ->
        !harnessOnlyMethods(f) &&
        !f.isView &&
        (is_withdraw_method(f) || is_redeem_method(f) ||
         f.selector == withdrawFees(address,uint256).selector
        )
}
{
    getCLMFees_LEQ_ATokenBAL_2(f);
}
