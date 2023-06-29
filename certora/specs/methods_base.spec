import "erc20.spec"

using AToken as _AToken
using DummyERC20_aTokenUnderlying as Underlying
using SymbolicLendingPoolL1 as _SymbolicLendingPoolL1
using ATokenVaultHarness as _ATokenVaultHarness

methods{
    deposit(uint256, address) returns (uint256);
    //depositATokensWithSig(uint256, address, address, (uint8,bytes32,bytes32,uint256)) returns (uint256);
    depositATokensWithSig(uint256, address, address, _ATokenVaultHarness.EIP712Signature) returns (uint256);

    maxDeposit(address) returns (uint256) envfree;
    maxRedeem(address) returns (uint256);

    getFee() returns (uint256) envfree
    owner() returns (address) envfree
    totalSupply() returns uint256 envfree
    balanceOf(address) returns (uint256) envfree
    getLastVaultBalance() returns (uint256) envfree;
    getAccumulatedFees() returns (uint128) envfree;
    maxAssetsWithdrawableFromAave() returns (uint256) envfree;
    
    mulDivWrapper(uint256, uint256, uint256, uint8) envfree;
    previewRedeem(uint256) returns (uint256); 

    _AToken.totalSupply() returns uint256 envfree;
    _AToken.balanceOf(address) returns (uint256) envfree;
    _AToken.scaledTotalSupply() returns (uint256) envfree;
    _AToken.scaledBalanceOf(address) returns (uint256) envfree;
    _AToken.transferFrom(address,address,uint256) returns (bool);

    Underlying.balanceOf(address) returns (uint256) envfree;

    // //*********************  AToken.sol ********************************
    // // The following was copied from StaticATokenLM spec file
    // //*****************************************************************
    //    mint(address,address,uint256,uint256) returns (bool) => DISPATCHER(true)
    //burn(address,address,uint256,uint256) returns (bool) => DISPATCHER(true)
    getIncentivesController() returns (address) => CONSTANT;
    UNDERLYING_ASSET_ADDRESS() returns (address) => CONSTANT;


    // called by AToken.sol::224. A method of IPool.
    finalizeTransfer(address, address, address, uint256, uint256, uint256) => NONDET

    // called from: IncentivizedERC20.sol::207. A method of incentivesControllerLocal.
    handleAction(address,uint256,uint256) => NONDET

    // getPool() returns address => ALWAYS(100);
    getPool() returns address => NONDET;
    
    // // nissan Remark: not sure about the following 3 summarizations:

    // A method of Ipool
    // can this contract change the pool
    getReserveData(address) => CONSTANT;
    
    claimAllRewards(address[],address) => NONDET;

    // called in MetaTxHelpers.sol::27.
    isValidSignature(bytes32, bytes) => NONDET;
}

definition RAY() returns uint256 = 10^27;
definition RAY_HALF() returns uint256 = 5*10^26;
// In file Constants.sol we have "uint256 constant SCALE = 1e18;"
definition SCALE() returns uint256 = 1000000000000000000;

definition harnessOnlyMethods(method f) returns bool =
    (f.selector == havoc_all().selector ||
     f.selector == accrueYield().selector ||
     f.selector == getAccumulatedFees().selector ||
     f.selector == mulDiv__(uint256,uint256,uint256,uint8).selector ||
     f.selector == rayMul__(uint256,uint256).selector ||
     f.selector == rayDiv__(uint256,uint256).selector ||
     f.selector == handleDeposit_wrapper(uint256,address,address, bool).selector ||
     f.selector == handleMint_wrapper(uint256,address,address,bool).selector ||
     f.selector == handleWithdraw_wrapper(uint256,address,address,address,bool).selector ||
     f.selector == handleRedeem_wrapper(uint256,address,address,address,bool).selector
    );

definition is_depositSig_method(method f) returns bool =
    (
     f.selector == depositWithSig(uint256,address,address,
                                  (uint8,bytes32,bytes32,uint256)).selector ||
     f.selector == depositATokensWithSig(uint256,address,address,
                                         (uint8,bytes32,bytes32,uint256)).selector
    );
definition is_mintSig_method(method f) returns bool =
    (
     f.selector == mintWithATokensWithSig(uint256,address,address,
                                          (uint8,bytes32,bytes32,uint256)).selector ||
     f.selector == mintWithSig(uint256,address,address,
                               (uint8,bytes32,bytes32,uint256)).selector
    );
definition is_withdrawSig_method(method f) returns bool =
    (
     f.selector == withdrawWithSig(uint256,address,address,
                                   (uint8,bytes32,bytes32,uint256)).selector ||
     f.selector == withdrawATokensWithSig(uint256,address,address,
                                          (uint8,bytes32,bytes32,uint256)).selector
    );
definition is_redeemSig_method(method f) returns bool =
    (
     f.selector == redeemWithSig(uint256,address,address,
                                 (uint8,bytes32,bytes32,uint256)).selector ||
     f.selector == redeemWithATokensWithSig(uint256,address,address,
                                            (uint8,bytes32,bytes32,uint256)).selector
    );

definition is_sig_method(method f) returns bool =
    (
     is_depositSig_method(f) || is_mintSig_method(f) || is_withdrawSig_method(f) || is_redeemSig_method(f)
    );


definition is_deposit_method(method f) returns bool =
    (f.selector == deposit(uint256, address).selector ||
     f.selector == depositATokens(uint256, address).selector ||
     is_depositSig_method(f)
    );
definition is_mint_method(method f) returns bool =
    (f.selector == mint(uint256, address).selector ||
     f.selector == mintWithATokens(uint256,address).selector ||
     is_mintSig_method(f)
    );
definition is_withdraw_method(method f) returns bool =
    (
     f.selector == withdraw(uint256,address,address).selector ||
     f.selector == withdrawATokens(uint256,address,address).selector ||
     is_withdrawSig_method(f)
    );
definition is_redeem_method(method f) returns bool =
    (
     f.selector == redeem(uint256,address,address).selector ||
     f.selector == redeemAsATokens(uint256,address,address).selector ||
     is_redeemSig_method(f)
    );


// ghost variable to track the calling of _accrueYield function
ghost bool accrueYieldCalled{
    init_state axiom accrueYieldCalled == false;
}


// **********************************************
// ATokenVault
// **********************************************
ghost sumAllBalance() returns mathint {
    init_state axiom sumAllBalance() == 0;
}

hook Sstore _balances[KEY address a] uint256 balance (uint256 old_balance) STORAGE {
  havoc sumAllBalance assuming sumAllBalance@new() == sumAllBalance@old() + balance - old_balance;
}

hook Sload uint256 balance _balances[KEY address a] STORAGE {
    require balance <= sumAllBalance();
}


// **********************************************
// UNDERLYING
// **********************************************
ghost sumAllBalance_underline() returns mathint {
    init_state axiom sumAllBalance_underline() == 0;
}

hook Sstore Underlying.b[KEY address a] uint256 balance (uint256 old_balance) STORAGE {
  havoc sumAllBalance_underline assuming sumAllBalance_underline@new() == sumAllBalance_underline@old() + balance - old_balance;
}

hook Sload uint256 balance Underlying.b[KEY address a] STORAGE {
    require balance <= sumAllBalance_underline();
}


// **********************************************
// ATOKEN
// **********************************************
ghost sumAllBalance_atoken() returns mathint {
    init_state axiom sumAllBalance_atoken() == 0;
}

hook Sstore _AToken._userState[KEY address a] .(offset 0) uint128 balance (uint128 old_balance) STORAGE {
  havoc sumAllBalance_atoken assuming sumAllBalance_atoken@new() == sumAllBalance_atoken@old() + balance - old_balance;
}

hook Sload uint128 balance _AToken._userState[KEY address a] .(offset 0) STORAGE {
    require balance <= sumAllBalance_atoken();
}




// *********** CVL functions ************* //

// Empty CVL function to bypass the _accrueYield function
function ay(){
    uint40 sum = 1;
}


function maxUint132() returns uint256 {return 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;}
function maxUint128() returns uint128 {return 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;}
                                              
function maxUint120() returns uint128 {return 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;}

// axiom f * deno < x*y
// axioms for requirement in CVL function

function accrueYieldSummary(){
    accrueYieldCalled = true;
}
