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

    public func clear() {
        loans := M.HashMap<Nat, T.Loan>(10, Nat.equal, Hash.hash);
        book.clear();
        pool.clear();
    };

    // ===== LOAN FUNCTIONS =====
    public shared(msg) func addLoan(juniorAmount: Nat, seniorAmount: Nat, interest: Nat) : async T.AddLoanReceipt {
        let id = nextId();
        Debug.print("");
        let owner=msg.caller;
        let startTime = Time.now();

        let status = #initiated;

        let loan : T.Loan = {
            id;
            status;
            owner;
            juniorAmount;
            seniorAmount;
            interest;
            startTime;
         };
        loans.put(id, loan);

        #Ok(loans.get(id))
    };

    public shared(msg) func cancelLoan(loan_id: Nat) : async T.CancelLoanReceipt {
        Debug.print("Cancelling loan "# Nat.toText(loan_id) #"...");
        switch (loans.get(loan_id)) {
            case (?loan)
                if(loan.owner != msg.caller or loan.status != #initiated) {
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
            case (?loan) return ?loan;
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
    public shared(msg) func withdrawFund(loanId: Nat, address: Principal) : async T.WithdrawReceipt {
        switch (loans.get(loanId)) {
            case (?loan){
                if(msg.caller != loan.owner and loan.status != #approved) {
                    return #Err(#TransferFailure);
                }
                else{                    
                    let account_id = Account.accountIdentifier(address, Account.defaultSubaccount());
                    let amount = loan.juniorAmount + loan.seniorAmount;
                    let withdrawreceipt =    await Ledger.transfer({
                                                        memo: Nat64    = 0;
                                                        from_subaccount = ?Account.defaultSubaccount();
                                                        to = account_id;
                                                        amount = { e8s = Nat64.fromNat(amount) };
                                                        fee = { e8s = Nat64.fromNat(icp_fee) };
                                                        created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(Time.now())) };
                                                    });


                    switch withdrawreceipt {
                        case (#Ok _) {
                            let id = loan.id;
                            let owner = loan.owner;
                            let juniorAmount = loan.juniorAmount;
                            let seniorAmount = loan.seniorAmount;
                            let status = #raised;
                            let interest = loan.interest;
                            let startTime = Time.now();

                            let updated_loan : T.Loan = {
                                id;
                                status;
                                owner;
                                juniorAmount;
                                seniorAmount;
                                interest;
                                startTime;
                            };
                            loans.put(loanId, updated_loan);
                            return #Ok(amount)
                        };
                        case _ {return #Err(#TransferFailure);};
                    };
                };
            };
            case null {return #Err(#TransferFailure);}
        };
    };

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
            amount = { e8s = Nat64.fromNat(amount) };
            fee = { e8s = Nat64.fromNat(icp_fee) };
            created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(Time.now())) };
        });

        switch icp_reciept {
            case (#Err e) {
                // add tokens back to user account balance
                pool.depositFunds(caller,amount);
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
    public shared(msg) func getCanisterICPAddress(): async Blob {
        Account.accountIdentifier(Principal.fromActor(this), Account.defaultSubaccount());
    };

    public shared(msg) func getDepositAddress(): async Blob {
        Account.accountIdentifier(Principal.fromActor(this), Account.principalToSubaccount(msg.caller));
    };

    public func getLoanInterestAmount(loanId: Nat): async Nat {
        switch (loans.get(loanId)) {
            case (?loan){
                let interest_amount =  getInterestAmount(loan);
                return interest_amount;
            };
            
            case null {return 0;}
        };
        
    };
    private func getInterestAmount(loan: T.Loan): Nat {
        let interest_per_year = (loan.juniorAmount + loan.seniorAmount) * loan.interest;
        let interest_per_nano = interest_per_year / 31557000000000000;
        let interest_amount = Int.abs(Time.now() - loan.startTime) * interest_per_nano;
        return interest_amount;
    };
    public shared(msg) func payInterest(loanId: Nat): async T.DepositReceipt {
        // Debug.print("Depositing loan. LEDGER: " # Principal.toText(E.ledger()));
        switch (loans.get(loanId)) {
            case (?loan){
                if(loan.status != #raised) {
                    return #Err(#DepositError);
                };

                let caller = msg.caller;
                let interest_amount = getInterestAmount(loan);
                
                let source_account = Account.accountIdentifier(Principal.fromActor(this), Account.principalToSubaccount(caller));
                
                // Check ledger for value
                let balance = await Ledger.account_balance({ account = source_account });

                Debug.print("Source Account : "# Principal.toText(caller) #" ... Balance : " # Nat64.toText(balance.e8s));
                // Transfer to default subaccount
                let icp_receipt = if (Nat64.toNat(balance.e8s) > (interest_amount + icp_fee )) {
                    await Ledger.transfer({
                        memo: Nat64    = 0;
                        from_subaccount = ?Account.principalToSubaccount(caller);
                        to = Account.accountIdentifier(Principal.fromActor(this), Account.defaultSubaccount());
                        amount = { e8s = Nat64.fromNat(interest_amount) };
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
                // Return result
                return #Ok(interest_amount)

            };
            case null {return #Err(#DepositError);}
        };
    };

    public shared(msg) func deposit(loanId: Nat, depositAmount: Nat): async T.DepositReceipt {
        // Debug.print("Depositing loan. LEDGER: " # Principal.toText(E.ledger()));
        await depositIcp(msg.caller, loanId, depositAmount);
    };

    // After user transfers ICP to the target subaccount
    private func depositIcp(caller: Principal, loanId: Nat, depositAmount: Nat): async T.DepositReceipt {

        if(loanId != 0){
            switch (loans.get(loanId)) {
                case (?loan){
                    if(loan.status != #initiated) {
                        return #Err(#DepositError);
                    };
                    let total_committed : Nat = book.totalCommitted(loanId);
                    if(total_committed + depositAmount > loan.juniorAmount){return #Err(#DepositError);};
                };
                case null {return #Err(#DepositError);}
            };
        };
        // Calculate target subaccount
        // NOTE: Should this be hashed first instead?
        let source_account = Account.accountIdentifier(Principal.fromActor(this), Account.principalToSubaccount(caller));
        // let source_account = Account.principalToSubaccount(caller);

        // Check ledger for value
        let balance = await Ledger.account_balance({ account = source_account });

        Debug.print("Source Account : "# Principal.toText(caller) #" ... Balance : " # Nat64.toText(balance.e8s));

        // Transfer to default subaccount
        let icp_receipt = if (Nat64.toNat(balance.e8s) > (depositAmount + icp_fee )) {
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
        if(loanId == 0){
            //Senior loan, add to pool
            pool.depositFunds(caller,depositAmount);
        }
        else{
            //Junior loan, add to loan
            book.addLoan(caller,loanId,depositAmount);

            switch (loans.get(loanId)) {
                case (?loan){
                    let total_committed : Nat = book.totalCommitted(loanId);
                    if(total_committed == loan.juniorAmount){
                        let id = loan.id;
                        let owner = loan.owner;
                        let juniorAmount = loan.juniorAmount;
                        let seniorAmount = loan.seniorAmount;
                        let status = #approved;
                        let interest = loan.interest;
                        let startTime = Time.now();

                        let updated_loan : T.Loan = {
                            id;
                            status;
                            owner;
                            juniorAmount;
                            seniorAmount;
                            interest;
                            startTime;
                        };
                        loans.put(loanId, updated_loan);                        
                    };
                };
                case null {}
            } ;
        };

        // Return result
        #Ok(depositAmount)
    };
}
