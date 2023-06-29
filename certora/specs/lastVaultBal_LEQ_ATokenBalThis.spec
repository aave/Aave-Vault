import "methods_base.spec"

methods {
    Underlying.totalSupply() envfree;
    havoc_all() envfree;
    _SymbolicLendingPoolL1.getLiquidityIndex() envfree;

    rayMul(uint256 a,uint256 b) returns (uint256) => rayMul_g(a,b);
    rayDiv(uint256 a,uint256 b) returns (uint256) => rayDiv_g(a,b);
    mulDiv(uint256 x, uint256 y, uint256 denominator) returns uint256 => mulDiv3_g(x,y,denominator);
    
    havoc_all_dummy() => HAVOC_ALL;
}

ghost mulDiv3_g(uint256 , uint256 , uint256) returns uint256 {
    axiom forall uint256 x. forall uint256 y. forall uint256 denominator.
        mulDiv3_g(x,y,denominator)*denominator <= x*y;
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
// The main invariant of this file:
// _s.lastVaultBalance <= ATOKEN.balanceOf(theVault).
//
// Status: pass for all methods.
//
// Note: We require that the totalSupply of currentContract, AToken, Underlying to be
//       less than maxUint128() to avoid failures due to overflows.
// ******************************************************************************


rule lastVaultBalance_LEQ_ATokenBalThis(env e, method f) filtered {f ->
    f.selector != initialize(address,uint256,string,string,uint256).selector &&
    !harnessOnlyMethods(f) &&
    !f.isView
    //    f.selector != havoc_all().selector
}
{
    require e.msg.sender != currentContract;
    require getFee() <= SCALE();  // SCALE is 10^18
    //require _AToken.balanceOf(currentContract) <= maxUint128();
    //require totalSupply() <= maxUint128();
    //require Underlying.totalSupply() <= maxUint128();
    //require _AToken.scaledTotalSupply() <= maxUint128();
    requireInvariant inv_sumAllBalance_eq_totalSupply__underline(); 
    requireInvariant inv_sumAllBalance_eq_totalSupply__atoken(); 
    requireInvariant inv_sumAllBalance_eq_totalSupply();
    
    // The following require means: (x/ind+z)*ind == x+z*ind +-1
    
    require (forall uint256 x. forall uint256 ind. forall uint256 z.
             rayMul_g(to_uint256(rayDiv_g(x,ind)+z),ind) == to_uint256(x+rayMul_g(z,ind))
             ||
             rayMul_g(to_uint256(rayDiv_g(x,ind)+z),ind) == to_uint256(x+rayMul_g(z,ind))+1
             ||
             rayMul_g(to_uint256(rayDiv_g(x,ind)+z),ind)+1 == to_uint256(x+rayMul_g(z,ind))
             );
    //    require (forall uint256 x. forall uint256 ind. forall uint256 z.
    //         rayMul_g(to_uint256(rayDiv_g(x,ind)+z),ind) == to_uint256(x+rayMul_g(z,ind))
    //        );
    

    require (getLastVaultBalance() <= _AToken.balanceOf(currentContract));
    //    uint256 _last_vault_bal = getLastVaultBalance();
    // uint256 _atoken_bal = _AToken.balanceOf(currentContract);
    //uint256 _the_diff = _last_vault_bal <= _atoken_bal ? 0 : _last_vault_bal-_atoken_bal;

    if (f.selector == withdrawFees(address,uint256).selector) {
        address to; uint256 amount;
        require to != currentContract;
        withdrawFees(e,to,amount);
    }
    else if (f.selector == depositATokensWithSig(uint256,address,address,
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

    assert (getLastVaultBalance() <= _AToken.balanceOf(currentContract));

    //uint256 last_vault_bal_ = getLastVaultBalance();
    //uint256 atoken_bal_ = _AToken.balanceOf(currentContract);
    //uint256 the_diff_ = last_vault_bal_ <= atoken_bal_ ? 0 : last_vault_bal_-atoken_bal_;

    //assert (the_diff_ <= _the_diff + 1);
}


