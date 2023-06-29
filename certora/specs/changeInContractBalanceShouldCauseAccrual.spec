import "methods_base.spec"


methods{
    //    mulDiv(uint256 x, uint256 y, uint256 denominator, uint8 rounding) returns (uint256) envfree => mulDiv_g(x,y,denominator,rounding);
    mulDiv(uint256 x, uint256 y, uint256 denominator, uint8 rounding) returns (uint256) envfree => mulDiv4_g(x,y,denominator,rounding);
    rayMul(uint256 x, uint256 y) returns (uint256) envfree => rayMul_g(x,y);
    rayDiv(uint256 x, uint256 y) returns (uint256) envfree => rayDiv_g(x,y);

    _accrueYield() envfree => accrueYieldSummary()
}

ghost mulDiv4_g(uint256 , uint256 , uint256, uint8) returns uint256 {
    axiom 1==1;
}

ghost rayMul_g(uint256, uint256) returns uint256{
    axiom 1==1;
    //    axiom forall uint256 x. forall uint256 y. rayMul_g(x,y)*RAY()<= x*y + RAY()/2;
    //axiom forall uint256 x. forall uint256 y. x*y - RAY()/2< rayMul_g(x,y)*RAY();
}

ghost rayDiv_g(uint256, uint256) returns uint256{
    axiom 1==1;
    //    axiom forall uint256 x. forall uint256 y. rayDiv_g(x,y)*y<= x*RAY() + y/2;
    //axiom forall uint256 x. forall uint256 y. x*RAY() - y/2 < rayDiv_g(x,y)*y;
}


// STATUS: Verified
// rule to check that accrueYield function is called everytime some function causes a change 
// in the contract balances. This is crucial for correct accrual of fee.
rule changeInContractBalanceShouldCauseAccrual(env e, method f)
filtered { f -> !harnessOnlyMethods(f) && !f.isView }
{
    uint256 _contractATokenBal = _AToken.balanceOf(currentContract);
    uint256 _contractULBal = Underlying.balanceOf(currentContract);
    // uint256 _lastUpdated = getLastUpdated();
    // require _lastUpdated + e.block.timestamp <= 0xffffffffff;
    
    calldataarg args;
    f(e, args);

    // uint256 lastUpdated_ = getLastUpdated();
    // uint256 lastVaultBalance_ = getLastVaultBalance();
    uint256 contractATokenBal_ = _AToken.balanceOf(currentContract);
    uint256 contractULBal_ = Underlying.balanceOf(currentContract);
    assert (contractATokenBal_ != _contractATokenBal || _contractULBal != contractULBal_) && 
            (f.selector != withdrawFees(address, uint256).selector && 
            f.selector != emergencyRescue(address, address, uint256).selector) => 
            accrueYieldCalled == true,
            "contract balance change should trigger yield accrual";
}

