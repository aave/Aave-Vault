import "methods_base.spec";

methods {
    function rayMul__(uint256 a,uint256 b) external returns (uint256) envfree;
    function rayDiv__(uint256 a,uint256 b) external returns (uint256) envfree ;
    function mulDiv__(uint256 x, uint256 y, uint256 deno, MathUpgradeable.Rounding rounding) external returns(uint256) envfree;
}


// ******************************************************************************
// We prover here basic properties of rayMul/rayDiv/mulDiv.
// We use these properties in the summarization of the above in other files.
//
// Status: all rules pass.
// ******************************************************************************

rule rayMul_prop_1() {
    uint256 x;
    uint256 ind;
    uint256 z;
    
    require (RAY() <= ind);
    require (to_mathint(ind) <= 2*RAY());

    uint256 a = rayMul__(require_uint256(rayDiv__(x,ind)+z),ind);
    uint256 b = require_uint256(x+rayMul__(z,ind));
    assert a==b || to_mathint(a)==b+1 || to_mathint(b)==a+1;
}


rule rayMul_prop_2() {
    uint256 x;
    uint256 ind;
    uint256 z;
    
    require (RAY() <= ind);
    require (to_mathint(ind) <= 2*RAY());

    uint256 c = rayMul__(require_uint256(z-rayDiv__(x,ind)),ind);
    uint256 d = require_uint256(rayMul__(z,ind)-x);
    assert c==d || to_mathint(c)==d+1 || to_mathint(d)==c+1;
}

rule mulDiv_properties() {
    uint256 assets;
    MathUpgradeable.Rounding rnd;

    uint256 totA;
    uint256 totS;

    require (assets <= assert_uint256(maxUint128()));
    require (totA <= assert_uint256(maxUint128()));
    require (totS <= assert_uint256(maxUint128()));

    uint256 calc = mulDiv__(assets,totS,totA,rnd);

    //    assert totA-assets == 0  =>  totS-mulDiv__(assets,totS,totA,rnd) == 0;
    assert totA==assets  =>  totS == calc;
}
