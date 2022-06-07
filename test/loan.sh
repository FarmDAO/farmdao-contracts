set -x
set -e
trap 'catch' ERR
catch() {
  dfx identity use default
  echo "FAIL"
  exit 1
}
dfx identity use default
dfx identity new user1 || true
dfx identity new user2 || true
dfx identity use user1
dfx identity get-principal
export USER1=$(dfx identity get-principal)
echo USER1 "${USER1}"
export ICP_DEPOSIT_ADDR_USER1=$(dfx canister call defi_dapp getDepositAddress | tr -d '\n' | sed 's/,)/)/')
dfx identity use default
dfx canister call ledger transfer "(record { amount = record { e8s = 50000 }; to = $ICP_DEPOSIT_ADDR_USER1; fee = record { e8s = 10000}; memo = 1;})"
dfx identity use user2
dfx identity get-principal
export USER2=$(dfx identity get-principal)
echo USER2 "${USER2}"
export ICP_DEPOSIT_ADDR_USER2=$(dfx canister call defi_dapp getDepositAddress | tr -d '\n' | sed 's/,)/)/')
dfx identity use default
dfx canister call ledger transfer "(record { amount = record { e8s = 50000 }; to = $ICP_DEPOSIT_ADDR_USER2; fee = record { e8s = 10000}; memo = 1;})"
dfx identity use default
dfx canister call defi_dapp addLoan "(20000: nat, 80000: nat)"
dfx canister call defi_dapp getLoans
dfx identity use user1
dfx canister call defi_dapp getBalance "(1: nat)"
dfx identity use user2
dfx canister call defi_dapp getBalance "(1: nat)"
dfx identity use user1
dfx canister call defi_dapp deposit "(1: nat, 1000: nat)"
echo "expect user1 1000 loan 1"
dfx canister call defi_dapp getAllBalances
dfx canister call defi_dapp getAllBalances | grep -B1 -A2 1 | grep -A2 $USER1 | grep "amount = 4_000"
dfx identity use default
echo "PASS"