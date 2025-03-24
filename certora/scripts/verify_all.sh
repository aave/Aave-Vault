#CMN="--compilation_steps_only"




echo
echo "===================  1:changeInContractBalanceShouldCauseAccrual.conf"
certoraRun $CMN certora/conf/changeInContractBalanceShouldCauseAccrual.conf \
           --msg "1. changeInContractBalanceShouldCauseAccrual.conf"

echo
echo "===================  2:erc4626-previewOPERATIONS.conf"
certoraRun $CMN certora/conf/erc4626-previewOPERATIONS.conf    \
           --msg "2. erc4626-previewOPERATIONS.conf"

echo
echo "===================  3:fees_LEQ_ATokenBal.conf"
certoraRun $CMN certora/conf/fees_LEQ_ATokenBal.conf   \
           --msg "3. fees_LEQ_ATokenBal.conf"

echo
echo "===================  4:lastVaultBalance_LEQ_ATokenBalThis.conf"
certoraRun $CMN certora/conf/lastVaultBalance_LEQ_ATokenBalThis.conf \
          --msg "4. lastVaultBalance_LEQ_ATokenBalThis.conf"

echo
echo "===================  5:positiveSupply_imply_positiveAssets-deposit.conf"
certoraRun $CMN certora/conf/positiveSupply_imply_positiveAssets-deposit.conf \
           --msg "5.positiveSupply_imply_positiveAssets-deposit.conf"

echo
echo "===================  6:positiveSupply_imply_positiveAssets-mint.conf"
certoraRun $CMN certora/conf/positiveSupply_imply_positiveAssets-mint.conf \
           --msg "6.positiveSupply_imply_positiveAssets-mint.conf"

echo
echo "===================  7:positiveSupply_imply_positiveAssets-other.conf"
certoraRun $CMN certora/conf/positiveSupply_imply_positiveAssets-other.conf \
           --msg "7.positiveSupply_imply_positiveAssets-other.conf"

echo
echo "===================  8:positiveSupply_imply_positiveAssets-redeem.conf"
certoraRun $CMN certora/conf/positiveSupply_imply_positiveAssets-redeem.conf \
           --msg "8.positiveSupply_imply_positiveAssets-redeem.conf"

echo
echo "===================  9:positiveSupply_imply_positiveAssets-withdraw.conf"
certoraRun $CMN certora/conf/positiveSupply_imply_positiveAssets-withdraw.conf \
           --msg "9.positiveSupply_imply_positiveAssets-withdraw.conf"

echo
echo "===================  10:rayMul_rayDiv_mulDiv_properties.conf"
certoraRun $CMN certora/conf/rayMul_rayDiv_mulDiv_properties.conf \
           --msg "10.rayMul_rayDiv_mulDiv_properties.conf"

echo
echo "===================  11:totalSupply_EQ_sumAllBal.conf"
certoraRun $CMN certora/conf/totalSupply_EQ_sumAllBal.conf \
           --msg "11.totalSupply_EQ_sumAllBal.conf"

echo
echo "===================  12:accrueYieldCheck.conf"
certoraRun $CMN certora/conf/accrueYieldCheck.conf \
           --msg "12.accrueYieldCheck.conf"

