import "methods_base.spec";


// Rule to check the _accrueYield function
// 1. _s.accumulatedFees monotonically increases

// STATUS: Verified
rule accrueYieldCheck(env e){
    uint128 _accumulatedFees = getAccumulatedFees();
    accrueYield(e);
    uint128 accumulatedFees_ = getAccumulatedFees();
    
    assert _accumulatedFees <= accumulatedFees_,"accumulated fee can only increase or stay the same";
}


