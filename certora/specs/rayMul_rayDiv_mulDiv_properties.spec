import "methods_base.spec"

methods {
    Underlying.totalSupply() envfree;
    havoc_all() envfree;
    _SymbolicLendingPoolL1.getLiquidityIndex() envfree;

    rayMul__(uint256 a,uint256 b) returns (uint256) envfree;
    rayDiv__(uint256 a,uint256 b) returns (uint256) envfree ;
    mulDiv__(uint256 x, uint256 y, uint256 deno, uint8 rounding) returns(uint256) envfree;

    //    mulDiv(uint256 x, uint256 y, uint256 denominator) returns uint256 => mulDiv3_g(x,y,denominator);
    
    havoc_all_dummy() => HAVOC_ALL;
}



rule rayMul_prop_1() {
    uint256 x;
    uint256 ind;
    uint256 z;
    
    require (RAY() <= ind);
    require (ind <= 2*RAY());

    uint256 a = rayMul__(to_uint256(rayDiv__(x,ind)+z),ind);
    uint256 b = to_uint256(x+rayMul__(z,ind));
    assert a==b || a==b+1 || b==a+1;
}


rule rayMul_prop_2() {
    uint256 x;
    uint256 ind;
    uint256 z;
    
    require (RAY() <= ind);
    require (ind <= 2*RAY());

    uint256 c = rayMul__(to_uint256(z-rayDiv__(x,ind)),ind);
    uint256 d = to_uint256(rayMul__(z,ind)-x);
    assert c==d || c==to_uint256(d+1) || d==to_uint256(c+1);
}

rule mulDiv_properties() {
    uint256 assets;
    uint8 rnd;

    uint256 totA;
    uint256 totS;

    require (assets <= maxUint128());
    require (totA <= maxUint128());
    require (totS <= maxUint128());

    uint256 calc = mulDiv__(assets,totS,totA,rnd);

    //    assert totA-assets == 0  =>  totS-mulDiv__(assets,totS,totA,rnd) == 0;
    assert totA==assets  =>  totS == calc;
}
