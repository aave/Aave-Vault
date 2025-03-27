import "erc20.spec";

using AToken as _AToken;
using DummyERC20_aTokenUnderlying as Underlying;
using SymbolicLendingPoolL1 as _SymbolicLendingPoolL1;
using ATokenVaultHarness as _ATokenVaultHarness;

methods{
    function deposit(uint256, address) external returns (uint256);
    //depositATokensWithSig(uint256, address, address, (uint8,bytes32,bytes32,uint256)) returns (uint256);
    function depositATokensWithSig(uint256, address, address, IATokenVault.EIP712Signature) external returns (uint256);

    function maxDeposit(address) external returns (uint256) envfree;
    function maxRedeem(address) external returns (uint256);

    function getFee() external returns (uint256) envfree;
    function owner() external returns (address) envfree;
    function totalSupply() external returns uint256 envfree;
    function balanceOf(address) external returns (uint256) envfree;
    function getLastVaultBalance() external returns (uint256) envfree;
    function getAccumulatedFees() external returns (uint128) envfree;
    function maxAssetsWithdrawableFromAave() external returns (uint256) envfree;
    
    function mulDiv__(uint256, uint256, uint256, MathUpgradeable.Rounding) external returns (uint256) envfree;
    function previewRedeem(uint256) external returns (uint256);

    function _AToken.totalSupply() external returns uint256 envfree;
    function _AToken.balanceOf(address) external returns (uint256) envfree;
    function _AToken.scaledTotalSupply() external returns (uint256) envfree;
    function _AToken.scaledBalanceOf(address) external returns (uint256) envfree;
    function _AToken.transferFrom(address,address,uint256) external returns (bool);

    function Underlying.balanceOf(address) external returns (uint256) envfree;
    function Underlying.totalSupply() external returns (uint256) envfree;

    // //*********************  AToken.sol ********************************
    // // The following was copied from StaticATokenLM spec file
    // //*****************************************************************
    //function _.mint(address,address,uint256,uint256) external returns (bool) => DISPATCHER(true);
    //function _.burn(address,address,uint256,uint256) external returns (bool) => DISPATCHER(true);
    //function _.getIncentivesController() external returns (address) => CONSTANT;
    //function _.UNDERLYING_ASSET_ADDRESS() external returns (address) => CONSTANT;

    //    function _.mint(address,address,uint256,uint256) internal => DISPATCHER(true);
    //function _.burn(address,address,uint256,uint256) internal => DISPATCHER(true);
    function _.getIncentivesController() external => CONSTANT;
    function _.UNDERLYING_ASSET_ADDRESS() external => CONSTANT;


    // called by AToken.sol::224. A method of IPool.
    function _.finalizeTransfer(address, address, address, uint256, uint256, uint256) external => NONDET;

    // called from: IncentivizedERC20.sol::207. A method of incentivesControllerLocal.
    function _.handleAction(address,uint256,uint256) external => NONDET;

    // getPool() returns address => ALWAYS(100);
    //    function _.getPool() external returns address => NONDET;
    function _.getPool() external => NONDET;
    
    // // nissan Remark: not sure about the following 3 summarizations:

    // A method of Ipool
    // can this contract change the pool
    function _.getReserveData(address) external => CONSTANT;
    
    function _.claimAllRewards(address[],address) external => NONDET;

    // called in MetaTxHelpers.sol::27.
    function _.isValidSignature(bytes32, bytes) external => NONDET;
}

definition RAY() returns uint256 = 10^27;
definition RAY_HALF() returns uint256 = 5*10^26;
// In file Constants.sol we have "uint256 constant SCALE = 1e18;"
definition SCALE() returns uint256 = 1000000000000000000;

definition harnessOnlyMethods(method f) returns bool =
    (f.selector == sig:havoc_all().selector ||
     f.selector == sig:accrueYield().selector ||
     f.selector == sig:getAccumulatedFees().selector ||
     f.selector == sig:mulDiv__(uint256,uint256,uint256,MathUpgradeable.Rounding).selector ||
     f.selector == sig:rayMul__(uint256,uint256).selector ||
     f.selector == sig:rayDiv__(uint256,uint256).selector ||
     f.selector == sig:handleDeposit_wrapper(uint256,address,address, bool).selector ||
     f.selector == sig:handleMint_wrapper(uint256,address,address,bool).selector ||
     f.selector == sig:handleWithdraw_wrapper(uint256,address,address,address,bool).selector ||
     f.selector == sig:handleRedeem_wrapper(uint256,address,address,address,bool).selector
    );

definition is_depositSig_method(method f) returns bool =
    (
     f.selector == sig:depositWithSig(uint256,address,address,
                                      IATokenVault.EIP712Signature).selector ||
     f.selector == sig:depositATokensWithSig(uint256,address,address,
                                             IATokenVault.EIP712Signature).selector
    );
definition is_mintSig_method(method f) returns bool =
    (
     f.selector == sig:mintWithSig(uint256,address,address,
                                   IATokenVault.EIP712Signature).selector ||
     f.selector == sig:mintWithATokensWithSig(uint256,address,address,
                                              IATokenVault.EIP712Signature).selector
    );
definition is_withdrawSig_method(method f) returns bool =
    (
     f.selector == sig:withdrawWithSig(uint256,address,address,
                                       IATokenVault.EIP712Signature).selector ||
     f.selector == sig:withdrawATokensWithSig(uint256,address,address,
                                              IATokenVault.EIP712Signature).selector
    );
definition is_redeemSig_method(method f) returns bool =
    (
     f.selector == sig:redeemWithSig(uint256,address,address,
                                     IATokenVault.EIP712Signature).selector ||
     f.selector == sig:redeemWithATokensWithSig(uint256,address,address,
                                                IATokenVault.EIP712Signature).selector
    );

definition is_sig_method(method f) returns bool =
    (
     is_depositSig_method(f) || is_mintSig_method(f) || is_withdrawSig_method(f) || is_redeemSig_method(f)
    );

definition is_deposit_method(method f) returns bool =
    (f.selector == sig:deposit(uint256, address).selector ||
     f.selector == sig:depositATokens(uint256, address).selector ||
     is_depositSig_method(f)
    );
definition is_mint_method(method f) returns bool =
    (f.selector == sig:mint(uint256, address).selector ||
     f.selector == sig:mintWithATokens(uint256,address).selector ||
     is_mintSig_method(f)
    );
definition is_withdraw_method(method f) returns bool =
    (
     f.selector == sig:withdraw(uint256,address,address).selector ||
     f.selector == sig:withdrawATokens(uint256,address,address).selector ||
     is_withdrawSig_method(f)
    );
definition is_redeem_method(method f) returns bool =
    (
     f.selector == sig:redeem(uint256,address,address).selector ||
     f.selector == sig:redeemAsATokens(uint256,address,address).selector ||
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

hook Sstore _balances[KEY address a] uint256 balance (uint256 old_balance) {
  havoc sumAllBalance assuming sumAllBalance@new() == sumAllBalance@old() + balance - old_balance;
}

hook Sload uint256 balance _balances[KEY address a] {
  require balance <= sumAllBalance();
}


// **********************************************
// UNDERLYING
// **********************************************
ghost sumAllBalance_underline() returns mathint {
    init_state axiom sumAllBalance_underline() == 0;
}

hook Sstore Underlying.b[KEY address a] uint256 balance (uint256 old_balance) {
  havoc sumAllBalance_underline assuming sumAllBalance_underline@new() == sumAllBalance_underline@old() + balance - old_balance;
}

hook Sload uint256 balance Underlying.b[KEY address a] {
    require to_mathint(balance) <= sumAllBalance_underline();
}


// **********************************************
// ATOKEN
// **********************************************
ghost sumAllBalance_atoken() returns mathint {
    init_state axiom sumAllBalance_atoken() == 0;
}

hook Sstore _AToken._userState[KEY address a] .(offset 0) uint128 balance (uint128 old_balance) {
  havoc sumAllBalance_atoken assuming sumAllBalance_atoken@new() == sumAllBalance_atoken@old() + balance - old_balance;
}

hook Sload uint128 balance _AToken._userState[KEY address a] .(offset 0) {
    require to_mathint(balance) <= sumAllBalance_atoken();
}




// *********** CVL functions ************* //

// Empty CVL function to bypass the _accrueYield function
function ay(){
    uint40 summ = 1;
}


function maxUint128() returns uint128 {return 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;}
function maxUint120() returns uint128 {return 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;}
//function maxUint64()  returns uint128 {return 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;}
//function maxUint64() returns uint128  {
//    return 0xFFFFFFFFFFFFFFFF;
//
//}



function accrueYieldSummary(){
    accrueYieldCalled = true;
}
