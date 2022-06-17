import Time "mo:base/Time";


module {

    public type Token = Principal;

    // public type LoanId = Nat32;
  
    public type LoanStatus = {
        #initiated;
        #approved;
        #raised;
        #repayed;
        #defaulted;
    };

    public type Loan = {
        id: Nat;
        status: LoanStatus;
        owner: Principal;
        juniorAmount: Nat;
        seniorAmount: Nat;
        interest: Nat;
        startTime: Time.Time;
    };
    
    // ledger types
    public type Operation = {
        #approve;
        #mint;
        #transfer;
        #transferFrom;
    };

 
    public type TransactionStatus = {
        #succeeded;
        #failed;
    };

    public type TxRecord = {
        caller: ?Principal;
        op: Operation; // operation type
        index: Nat; // transaction index
        from: Principal;
        to: Principal;
        amount: Nat;
        fee: Nat;
        timestamp: Time.Time;
        status: TransactionStatus;
    };

    // Dip20 token interface
    public type TxReceipt = {
        #Ok: Nat;
        #Err: {
            #InsufficientAllowance;
            #InsufficientBalance;
            #ErrorOperationStyle;
            #Unauthorized;
            #LedgerTrap;
            #ErrorTo;
            #Other;
            #BlockUsed;
            #AmountTooSmall;
        };
    };

    public type Metadata = {
        logo : Text; // base64 encoded logo or logo url
        name : Text; // token name
        symbol : Text; // token symbol
        decimals : Nat8; // token decimal
        totalSupply : Nat; // token total supply
        owner : Principal; // token owner
        fee : Nat; // fee for update calls
    };


    public type DIPInterface = actor {
        transfer : (Principal,Nat) ->  async TxReceipt;
        transferFrom : (Principal,Principal,Nat) -> async TxReceipt;
        allowance : (owner: Principal, spender: Principal) -> async Nat;
        getMetadata: () -> async Metadata;
    };

    // return types
    public type AddLoanErr = {
        #InvalidLoan;
        #LoansBookFull;
    };
    public type AddLoanReceipt = {
        #Ok: ?Loan;
        #Err: AddLoanErr;
    };
    public type CancelLoanErr = {
        #NotExistingLoan;
        #NotAllowed;
    };
    public type CancelLoanReceipt = {
        #Ok: Nat;
        #Err: CancelLoanErr;
    };
    public type WithdrawErr = {
        #BalanceLow;
        #TransferFailure;
    };
    public type WithdrawReceipt = {
        #Ok: Nat;
        #Err: WithdrawErr;  
    };
    public type DepositErr = {
        #BalanceLow;
        #TransferFailure;
        #DepositError;
    };
    public type DepositReceipt = {
        #Ok: Nat;
        #Err: DepositErr;
    };
    public type Balance = {
        owner: Principal;
        loanId: Nat;
        amount: Nat;
    };

}
