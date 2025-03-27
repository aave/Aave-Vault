import "methods_base.spec";


methods{
    function _.rayMul(uint256 a,uint256 b) internal => rayMul_g(a,b) expect uint256 ALL;
    function _.rayDiv(uint256 a,uint256 b) internal => rayDiv_g(a,b) expect uint256 ALL;
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator, MathUpgradeable.Rounding rounding) internal =>
      mulDiv4_g(x,y,denominator)  expect uint256 ALL;

    
    function _._accrueYield() internal => accrueYieldSummary() expect void;
}

ghost mulDiv4_g(uint256 , uint256 , uint256) returns uint256 {
    axiom 1==1;
}

ghost rayMul_g(uint256, uint256) returns uint256{
    axiom 1==1;
}

ghost rayDiv_g(uint256, uint256) returns uint256{
    axiom 1==1;
}


// STATUS: Verified
// rule to check that accrueYield function is called everytime some function causes a change 
// in the contract balances. This is crucial for correct accrual of fee.
rule changeInContractBalanceShouldCauseAccrual(env e, method f)
filtered { f -> !harnessOnlyMethods(f) && !f.isView && f.contract==currentContract}
{
    uint256 _contractATokenBal = _AToken.balanceOf(currentContract);
    uint256 _contractULBal = Underlying.balanceOf(currentContract);
    
    calldataarg args;
    f(e, args);

    uint256 contractATokenBal_ = _AToken.balanceOf(currentContract);
    uint256 contractULBal_ = Underlying.balanceOf(currentContract);
    assert (contractATokenBal_ != _contractATokenBal || _contractULBal != contractULBal_) && 
            (f.selector != sig:withdrawFees(address, uint256).selector && 
            f.selector != sig:emergencyRescue(address, address, uint256).selector) => 
            accrueYieldCalled == true,
            "contract balance change should trigger yield accrual";
}

