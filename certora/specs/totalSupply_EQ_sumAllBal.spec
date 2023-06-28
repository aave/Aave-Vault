import "methods_base.spec"

methods {
    Underlying.totalSupply() envfree;
    rayMul(uint256 a,uint256 b) returns (uint256) => rayMul_g(a,b);
    rayDiv(uint256 a,uint256 b) returns (uint256) => rayDiv_g(a,b);
    mulDiv(uint256 x, uint256 y, uint256 denominator) returns uint256 => mulDiv3_g(x,y,denominator);
}


ghost rayMul_g(uint256 , uint256) returns uint256 {
    axiom 1==1;
}
ghost rayDiv_g(uint256 , uint256) returns uint256 {
    axiom 1==1;
}
ghost mulDiv3_g(uint256 , uint256 , uint256) returns uint256 {
    axiom 1==1;
}



// **********************************************
// ATokenVault:
// The total supply of ATokenVault equals the sum of all users' balances.
//
// Status: pass
// **********************************************
invariant inv_sumAllBalance_eq_totalSupply()
    sumAllBalance() == totalSupply()
    filtered {f -> f.selector != havoc_all().selector}

invariant inv_balanceOf_leq_totalSupply(address user)
    balanceOf(user) <= totalSupply()
{
    preserved with (env e) {
        requireInvariant inv_sumAllBalance_eq_totalSupply();
    }
}


// **********************************************
// UNDERLYING:
// The total supply of UNDERLYING equals the sum of all users' balances.
//
// Status: pass
// Remark: This invariant doesn't check a property of the Vault.
//         We need it because requiring that Underlying.totalSupply() <= <limit>
//         guarntees that the balance of each user <= <limit>.
//         This help us to avoid failures due to overflows.
// **********************************************
invariant inv_sumAllBalance_eq_totalSupply__underline()
    sumAllBalance_underline() == Underlying.totalSupply()
    filtered {f -> !f.isView &&
    f.selector != havoc_all().selector
   }


// **********************************************
// ATOKEN:
// The scaled total supply of ATOKEN equals the sum of all users' scaled balances.
//
// Status: pass
// Remark: This invariant doesn't check a property of the Vault.
//         We need it because requiring that _AToken.scaledTotalSupply() <= <limit>
//         guarntees that the scaled-balance of each user <= <limit>.
//         This help us to avoid failures due to overflows.
// **********************************************
invariant inv_sumAllBalance_eq_totalSupply__atoken()
    sumAllBalance_atoken() == _AToken.scaledTotalSupply()
    filtered {f -> !f.isView &&
              f.selector != havoc_all().selector
   }







