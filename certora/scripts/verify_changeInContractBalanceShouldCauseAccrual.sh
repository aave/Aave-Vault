certoraRun certora/harness/ATokenVaultHarness.sol \
    certora/harness/DummyContract.sol \
    certora/harness/pool/SymbolicLendingPoolL1.sol \
    certora/harness/tokens/DummyERC20_aTokenUnderlying.sol \
    certora/munged/lib/aave-v3-core/contracts/protocol/tokenization/AToken.sol \
    --verify ATokenVaultHarness:certora/specs/changeInContractBalanceShouldCauseAccrual.spec \
    --link ATokenVaultHarness:AAVE_POOL=SymbolicLendingPoolL1 \
           ATokenVaultHarness:ATOKEN=AToken \
           ATokenVaultHarness:UNDERLYING=DummyERC20_aTokenUnderlying \
           ATokenVaultHarness:DUMMY=DummyContract \
           AToken:POOL=SymbolicLendingPoolL1 \
           AToken:_underlyingAsset=DummyERC20_aTokenUnderlying \
           SymbolicLendingPoolL1:underlyingToken=DummyERC20_aTokenUnderlying \
           SymbolicLendingPoolL1:aToken=AToken \
    --solc solc8.10 \
    --optimistic_loop \
    --staging pre_cvl2 \
    --packages @openzeppelin-upgradeable=certora/munged/lib/openzeppelin-contracts-upgradeable/contracts \
               @aave-v3-core=certora/munged/lib/aave-v3-core/contracts \
               @aave-v3-periphery=certora/munged/lib/aave-v3-periphery/contracts \
               @openzeppelin=certora/munged/lib/openzeppelin-contracts/contracts \
               @aave/core-v3=certora/munged/lib/aave-v3-core \
    --msg "accrueYieldCheck" \
    --settings  -t=2000,-mediumTimeout=1000,-depth=15    \
    --settings -enableEventReporting \
    --send_only \
    --rule_sanity basic \
    --rule changeInContractBalanceShouldCauseAccrual \

