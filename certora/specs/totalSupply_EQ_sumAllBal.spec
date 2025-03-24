import "methods_base.spec";

methods {
    //    function _.rayMul(uint256 a,uint256 b) internal returns (uint256) => rayMul_g(a,b);
    //function _.rayDiv(uint256 a,uint256 b) internal returns (uint256) => rayDiv_g(a,b);
    //function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal returns uint256 => mulDiv3_g(x,y,denominator);

    //function _.foo() external => fooImpl() expect uint256 ALL;
    
    function _.rayMul(uint256 a,uint256 b) internal => rayMul_g(a,b) expect uint256 ALL;
    function _.rayDiv(uint256 a,uint256 b) internal => rayDiv_g(a,b) expect uint256 ALL;
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal => mulDiv3_g(x,y,denominator)  expect uint256 ALL;
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
  sumAllBalance() == to_mathint(totalSupply())
  filtered {f -> f.contract==currentContract && f.selector != sig:havoc_all().selector}

invariant inv_balanceOf_leq_totalSupply(address user)
  balanceOf(user) <= totalSupply()
  filtered {f -> f.contract==currentContract}
{
  preserved with (env e) {
    requireInvariant inv_sumAllBalance_eq_totalSupply();
  }
}

rule my_rule() {
    address a;
    requireInvariant inv_sumAllBalance_eq_totalSupply();

    require balanceOf(a) <= totalSupply();

    address from; address to; uint256 amount;
    env e;
    transferFrom(e, from, to, amount);
    
    assert balanceOf(a) <= totalSupply();
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
    sumAllBalance_underline() == to_mathint(Underlying.totalSupply())
    filtered {f -> !f.isView &&
    f.selector != sig:havoc_all().selector
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
    sumAllBalance_atoken() == to_mathint(_AToken.scaledTotalSupply())
    filtered {f -> !f.isView &&
              f.selector != sig:havoc_all().selector
   }







