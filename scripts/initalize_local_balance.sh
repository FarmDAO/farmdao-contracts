#!/bin/bash

dfx identity use default
dfx canister call AkitaDIP20 transfer  '(principal '\"$1\"',40000000000)'
dfx canister call GoldenDIP20 transfer  '(principal '\"$1\"',40000000000)'
# script to retrieve default subaccount of II in hex format
II_ACCOUNT_ID_HEX=$(python3 ./scripts/principal_to_default_account_id.py $1)
echo $II_ACCOUNT_ID_HEX
# convert hex account ID to vec format
II_ACCOUNT_ID=$(python3 -c 'print("vec{" + ";".join([str(b) for b in bytes.fromhex("'$II_ACCOUNT_ID_HEX'")]) + "}")')
echo $II_ACCOUNT_ID
dfx canister call ledger transfer "(record { amount = record { e8s = 40000000000 }; to = $II_ACCOUNT_ID; fee = record { e8s = 10000}; memo = 1;})"