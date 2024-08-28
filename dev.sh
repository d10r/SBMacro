#nodemon -w src/ -w test/ -e sol -x forge test $@

# USDCx -> ETHx
export TOREX1_ADDR=0x269F9EF6868F70fB20DDF7CfDf69Fe1DBFD307dE

# ETHx -> USDCx
export TOREX2_ADDR=0x267264CFB67B015ea23c97C07d609FbFc06aDC17

nodemon -w src/ -w test/ -e sol -x ./run_test.sh base-mainnet SBMacroTest $@
