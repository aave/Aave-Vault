certoraRun --send_only certora/conf/erc4626-previewOPERATIONS.conf    

certoraRun --send_only certora/conf/totalSupply_EQ_sumAllBal.conf

certoraRun --send_only certora/conf/changeInContractBalanceShouldCauseAccrual.conf

certoraRun --send_only certora/conf/rayMul_rayDiv_mulDiv_properties.conf    

certoraRun --send_only certora/conf/lastVaultBalance_LEQ_ATokenBalThis.conf    

certoraRun --send_only certora/conf/fees_LEQ_ATokenBal.conf   

certoraRun --send_only certora/conf/positiveSupply_imply_positiveAssets-mint.conf    

certoraRun --send_only certora/conf/positiveSupply_imply_positiveAssets-deposit.conf    

certoraRun --send_only certora/conf/positiveSupply_imply_positiveAssets-withdraw.conf    

certoraRun --send_only certora/conf/positiveSupply_imply_positiveAssets-redeem.conf   

certoraRun --send_only certora/conf/positiveSupply_imply_positiveAssets-other.conf

certoraRun --send_only certora/conf/accrueYieldCheck.conf
