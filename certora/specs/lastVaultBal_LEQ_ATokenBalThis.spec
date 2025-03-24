import "methods_base.spec";

methods {
    function havoc_all() external envfree;
    function SymbolicLendingPoolL1.getLiquidityIndex() external returns (uint256) envfree;
    function _.havoc_all_dummy() external => HAVOC_ALL;

    function _.rayMul(uint256 a,uint256 b) internal => rayMul_MI(a,b) expect uint256 ALL;
    function _.rayDiv(uint256 a,uint256 b) internal => rayDiv_MI(a,b) expect uint256 ALL;
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal => mulDiv3_g(x,y,denominator)  expect uint256 ALL;
}

ghost mulDiv3_g(uint256 , uint256 , uint256) returns uint256 {
    axiom forall uint256 x. forall uint256 y. forall uint256 denominator.
        mulDiv3_g(x,y,denominator)*denominator <= x*y;
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
// The main invariant of this file:
// _s.lastVaultBalance <= ATOKEN.balanceOf(theVault).
//
// Status: pass for all methods.
//
// Note: We require that the totalSupply of currentContract, AToken, Underlying to be
//       less than maxUint128() to avoid failures due to overflows.
// ******************************************************************************

rule lastVaultBalance_LEQ_ATokenBalThis(env e, method f) filtered {f ->
    f.selector != sig:initialize(address,uint256,string,string,uint256).selector &&
    !harnessOnlyMethods(f) &&
    !f.isView &&
    f.contract==currentContract
    }
{
    require e.msg.sender != currentContract;
    require getFee() <= SCALE();  // SCALE is 10^18
    //    require _AToken.balanceOf(currentContract) <= assert_uint256(maxUint128());
    //require totalSupply() <= assert_uint256(maxUint128());
    //require Underlying.totalSupply() <= assert_uint256(maxUint128());
    //require _AToken.scaledTotalSupply() <= assert_uint256(maxUint128());
    requireInvariant inv_sumAllBalance_eq_totalSupply__underline(); 
    requireInvariant inv_sumAllBalance_eq_totalSupply__atoken(); 
    requireInvariant inv_sumAllBalance_eq_totalSupply();
    
    // The following require means: (x/ind+z)*ind == x+z*ind +-1
    require (forall mathint x. forall mathint ind. forall mathint z.
             to_mathint(rayMul_MI((rayDiv_MI(x,ind)+z),ind)) == x+rayMul_MI(z,ind)
             ||
             to_mathint(rayMul_MI((rayDiv_MI(x,ind)+z),ind)) == x+rayMul_MI(z,ind)+1
             ||
             to_mathint(rayMul_MI((rayDiv_MI(x,ind)+z),ind))+1 == x+rayMul_MI(z,ind)
            );

    require (getLastVaultBalance() <= _AToken.balanceOf(currentContract));

    if (f.selector == sig:withdrawFees(address,uint256).selector) {
        address to; uint256 amount;
        require to != currentContract;
        withdrawFees(e,to,amount);
    }
    else if (f.selector == sig:depositATokensWithSig(uint256,address,address,
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

    assert (getLastVaultBalance() <= _AToken.balanceOf(currentContract));
}

