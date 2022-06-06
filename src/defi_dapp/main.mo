import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Bool "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Int64 "mo:base/Int64";
import Iter "mo:base/Iter";
import M "mo:base/HashMap";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";

import Account "./utils/Account";
import Ledger "canister:ledger";

import LB "LoansBook";
import SP "SeniorPool";
// import E "exchange";
import T "types";

shared(init_msg) actor class farmLoan() = this {
    // type LoanStatus = T.LoanStatus;

    let icp_fee: Nat = 10_000;

    stable var loans_stable : [T.Loan] = [];
    stable var lastId : Nat = 0;
    // var exchanges = M.HashMap<E.TradingPair, E.Exchange>(10, func (k1: E.TradingPair,k2: E.TradingPair): Bool {
    //     Principal.equal(k1.0,k2.0) and Principal.equal(k1.1,k2.1)
    // }, func (k : E.TradingPair) {
    //     Text.hash(Text.concat(Principal.toText(k.0),Principal.toText(k.1)))
    // });

    // User balance datastructure
    private var book = LB.LoansBook();
    private stable var book_stable : [var (Principal, [(T.Token, Nat)])] = [var];

    private var pool = SP.SeniorPool();

    var loans = M.HashMap<Nat, T.Loan>(10, Nat.equal, Hash.hash);

    // ===== LOAN FUNCTIONS =====
    public shared(msg) func addLoan(juniorAmount: Nat, seniorAmount: Nat) : async T.AddLoanReceipt {
        let id = nextId();
        Debug.print("");
        let owner=msg.caller;
        let submitted = Time.now();

        let status = #initiated;

        let loan : T.Loan = {
            id;
            status;
            owner;
            juniorAmount;
            seniorAmount;
         };
        loans.put(id, loan);

        #Ok(loans.get(id))
    };

    public shared(msg) func cancelLoan(loan_id: Nat) : async T.CancelLoanReceipt {
        Debug.print("Cancelling loan "# Nat.toText(loan_id) #"...");
        switch (loans.get(loan_id)) {
            case (?order)
                if(order.owner != msg.caller or order.status != #initiated) {
                    return #Err(#NotAllowed);
                } else {
                    //TODO: Return funds and set loan as canceled.
                };
            case null {}
        };
        return #Err(#NotExistingLoan);
    };

    public func getLoan(loan_id: Nat) : async(?T.Loan) {
        Debug.print("Checking loan "# Nat.toText(loan_id) #"...");
        switch (loans.get(loan_id)) {
            case (?order) return ?order;
            case null {}
        };
        null;
    };

    public func getLoans() : async([T.Loan]) {
        Debug.print("List loans...");
        getAllLoans()
    };

    private func getAllLoans() : [T.Loan] {

        let buff : Buffer.Buffer<T.Loan> = Buffer.Buffer(10);
        for(l in loans.vals()) {
            buff.add(l);
        };
        buff.toArray();
    };

    private func nextId() : Nat {
        lastId += 1;
        lastId;
    };

    // ===== WITHDRAW FUNCTIONS =====
    public shared(msg) func withdraw(amount: Nat, address: Principal) : async T.WithdrawReceipt {
        let account_id = Account.accountIdentifier(address, Account.defaultSubaccount());
        await withdrawIcp(msg.caller, amount, account_id)
    };

    private func withdrawIcp(caller: Principal, amount: Nat, account_id: Blob) : async T.WithdrawReceipt {
        Debug.print("Withdraw...");

        // remove withdrawal amount from senior pool
        switch (pool.withdrawFunds(caller, amount+icp_fee)){
            case(null){
                return #Err(#BalanceLow)
            };
            case _ {};
        };

        // Transfer amount back to user
        let icp_reciept =  await Ledger.transfer({
            memo: Nat64    = 0;
            from_subaccount = ?Account.defaultSubaccount();
            to = account_id;
            amount = { e8s = Nat64.fromNat(amount + icp_fee) };
            fee = { e8s = Nat64.fromNat(icp_fee) };
            created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(Time.now())) };
        });

        switch icp_reciept {
            case (#Err e) {
                // add tokens back to user account balance
                pool.depositFunds(caller,amount+icp_fee);
                return #Err(#TransferFailure);
            };
            case _ {};
        };
        #Ok(amount)
    };

    // ===== Loans STATE FUNCTIONS =====
    public shared query (msg) func getBalance(loanId: Nat) : async Nat {
        switch (book.get(msg.caller)) {
            case (?loan_balance) {
                switch (loan_balance.get(loanId)){
                    case (?balance) {
                        return balance;
                    };
                    case(null){
                        return 0;
                    };
                };
            };
            case (null) {
                return 0;
            };
        };
    };

    public shared query (msg) func getBalances() : async [T.Balance] {
        switch (book.get(msg.caller)) {
            case (?loan_balance) {
                Array.map<(Nat, Nat),T.Balance>(Iter.toArray(loan_balance.entries()), func (k : Nat, v: Nat) : T.Balance {
                    {
                        owner = msg.caller;
                        loanId = k;
                        amount = v;
                    }
                })
            };
            case (null) {
                return [];
            };
        };
    };


    public shared query (msg) func getAllBalances() : async [T.Balance] {
        
        // could probably allocate more but this is minimum
        let buff : Buffer.Buffer<T.Balance> = Buffer.Buffer(book.size());
        for ((owner, user_balances) in book.entries()) {
            let b : Buffer.Buffer<T.Balance> = Buffer.Buffer(user_balances.size());
            for ((loanId, amount) in user_balances.entries()) {
                b.add({
                    owner;
                    loanId;
                    amount;
                });
            };
            buff.append(b);
        };
        buff.toArray()
    };

    public shared query (msg) func whoami() : async Principal {
        return msg.caller;
    };


    // ===== DEPOSIT FUNCTIONS =====
    // Return the account ID specific to this user's subaccount
    public shared(msg) func getDepositAddress(): async Blob {
        Account.accountIdentifier(Principal.fromActor(this), Account.principalToSubaccount(msg.caller));
    };

    public shared(msg) func deposit(loanId: Nat, depositAmount: Nat): async T.DepositReceipt {
        // Debug.print("Depositing loan. LEDGER: " # Principal.toText(E.ledger()));
        await depositIcp(msg.caller, loanId, depositAmount);
    };

    // After user transfers ICP to the target subaccount
    private func depositIcp(caller: Principal, loanId: Nat, depositAmount: Nat): async T.DepositReceipt {

        // Calculate target subaccount
        // NOTE: Should this be hashed first instead?
        let source_account = Account.accountIdentifier(Principal.fromActor(this), Account.principalToSubaccount(caller));
        // let source_account = Account.principalToSubaccount(caller);

        // Check ledger for value
        let balance = await Ledger.account_balance({ account = source_account });

        Debug.print("Source Account : "# Principal.toText(caller) #" ... Balance : " # Nat64.toText(balance.e8s));

        // Transfer to default subaccount
        let icp_receipt = if (Nat64.toNat(balance.e8s) > (depositAmount + icp_fee)) {
            await Ledger.transfer({
                memo: Nat64    = 0;
                from_subaccount = ?Account.principalToSubaccount(caller);
                to = Account.accountIdentifier(Principal.fromActor(this), Account.defaultSubaccount());
                amount = { e8s = Nat64.fromNat(depositAmount) };
                fee = { e8s = Nat64.fromNat(icp_fee) };
                created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(Time.now())) };
            })
        } else {
            return #Err(#BalanceLow);
        };

        switch icp_receipt {
            case ( #Err _) {
                return #Err(#TransferFailure);
            };
            case _ {};
        };

        // keep track of deposited ICP
        book.addLoan(caller,loanId,depositAmount);

        // Return result
        #Ok(depositAmount)
    };
}
