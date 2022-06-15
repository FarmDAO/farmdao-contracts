set -x
set -e
trap 'catch' ERR
catch() {
  dfx identity use default
  echo "FAIL"
  exit 1
}
dfx identity use default
dfx canister call defi_dapp getLoanInterestAmount "(1: nat)"
dfx canister call defi_dapp getPoolBalance
dfx canister call defi_dapp getAllPoolBalances
dfx canister call defi_dapp payInterest "(1: nat)"
echo "PASS"