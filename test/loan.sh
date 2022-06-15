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
# dfx identity get-principal
export USER1=$(dfx identity get-principal)
echo USER1 "${USER1}"
export USERID1=$(dfx ledger account-id)
export ICP_DEPOSIT_ADDR_USER1=$(dfx canister call defi_dapp getDepositAddress | tr -d '\n' | sed 's/,)/)/')
dfx identity use default
dfx canister call ledger transfer "(record { amount = record { e8s = 5000000000 }; to = $ICP_DEPOSIT_ADDR_USER1; fee = record { e8s = 10000}; memo = 1;})"
dfx identity use user2
# dfx identity get-principal
export USER2=$(dfx identity get-principal)
echo USER2 "${USER2}"
export USERID2=$(dfx ledger account-id)
export ICP_DEPOSIT_ADDR_USER2=$(dfx canister call defi_dapp getDepositAddress | tr -d '\n' | sed 's/,)/)/')
dfx identity use default
dfx canister call ledger transfer "(record { amount = record { e8s = 5000000000 }; to = $ICP_DEPOSIT_ADDR_USER2; fee = record { e8s = 10000}; memo = 1;})"
dfx identity use default
#interest of 20% yearly
dfx canister call defi_dapp addLoan "(20000000: nat, 80000000: nat, 20: nat)"
dfx canister call defi_dapp getLoans
dfx identity use user1
dfx canister call defi_dapp getBalance "(1: nat)"
dfx identity use user2
dfx canister call defi_dapp getBalance "(1: nat)"
#Deposit and withdraw from pool
dfx identity use user1
dfx canister call defi_dapp deposit "(0: nat, 100000000: nat)"
dfx canister call ledger account_balance '(record { account = '$(python3 -c 'print("vec{" + ";".join([str(b) for b in bytes.fromhex('\"$USERID1\"')]) + "}")')' })'
dfx canister call defi_dapp withdraw '(15000000, principal '\"$USER1\"')'
dfx canister call ledger account_balance '(record { account = '$(python3 -c 'print("vec{" + ";".join([str(b) for b in bytes.fromhex('\"$USERID1\"')]) + "}")')' })'
#Deposit to loan to fulfill loan
dfx identity use user2
dfx canister call defi_dapp deposit "(1: nat, 10000000: nat)"
dfx canister call defi_dapp getLoans
dfx canister call defi_dapp deposit "(1: nat, 10000000: nat)"
dfx canister call defi_dapp getLoans
#Withdraw funds
dfx identity use default
dfx canister call defi_dapp withdrawFund '(1, principal '\"$USER1\"')'
dfx canister call ledger account_balance '(record { account = '$(python3 -c 'print("vec{" + ";".join([str(b) for b in bytes.fromhex('\"$USERID1\"')]) + "}")')' })'
#Pay interest
# dfx identity use user1
# dfx canister call defi_dapp payInterest '(1)'
# dfx canister call ledger account_balance '(record { account = '$(python3 -c 'print("vec{" + ";".join([str(b) for b in bytes.fromhex('\"$USERID1\"')]) + "}")')' })'
# dfx identity use user1
# dfx canister call defi_dapp deposit "(1: nat, 10000000: nat)"
# echo "expect user1 10000000 loan 1"
dfx canister call defi_dapp getAllBalances
#dfx canister call defi_dapp getAllBalances | grep -B1 -A2 1 | grep -A2 $USER1 | grep "amount = 1_000"
dfx identity use default
echo "PASS"