#nodemon -w src/ -w test/ -e sol -x forge test $@

# USDCx -> ETHx
export TOREX_ADDR=0x269F9EF6868F70fB20DDF7CfDf69Fe1DBFD307dE
nodemon -w src/ -w test/ -e sol -x ./run_test.sh base-mainnet SBMacroTest $@
