export const idlFactory = ({ IDL }) => {
  const Time = IDL.Int;
  const LoanStatus = IDL.Variant({
    'initiated' : IDL.Null,
    'approved' : IDL.Null,
    'repayed' : IDL.Null,
    'raised' : IDL.Null,
    'defaulted' : IDL.Null,
  });
  const Loan = IDL.Record({
    'id' : IDL.Nat,
    'startTime' : Time,
    'status' : LoanStatus,
    'interest' : IDL.Nat,
    'owner' : IDL.Principal,
    'juniorAmount' : IDL.Nat,
    'seniorAmount' : IDL.Nat,
  });
  const AddLoanErr = IDL.Variant({
    'LoansBookFull' : IDL.Null,
    'InvalidLoan' : IDL.Null,
  });
  const AddLoanReceipt = IDL.Variant({
    'Ok' : IDL.Opt(Loan),
    'Err' : AddLoanErr,
  });
  const CancelLoanErr = IDL.Variant({
    'NotAllowed' : IDL.Null,
    'NotExistingLoan' : IDL.Null,
  });
  const CancelLoanReceipt = IDL.Variant({
    'Ok' : IDL.Nat,
    'Err' : CancelLoanErr,
  });
  const DepositErr = IDL.Variant({
    'DepositError' : IDL.Null,
    'TransferFailure' : IDL.Null,
    'BalanceLow' : IDL.Null,
  });
  const DepositReceipt = IDL.Variant({ 'Ok' : IDL.Nat, 'Err' : DepositErr });
  const Balance = IDL.Record({
    'owner' : IDL.Principal,
    'loanId' : IDL.Nat,
    'amount' : IDL.Nat,
  });
  const WithdrawErr = IDL.Variant({
    'TransferFailure' : IDL.Null,
    'BalanceLow' : IDL.Null,
  });
  const WithdrawReceipt = IDL.Variant({ 'Ok' : IDL.Nat, 'Err' : WithdrawErr });
  const farmLoan = IDL.Service({
    'addLoan' : IDL.Func([IDL.Nat, IDL.Nat, IDL.Nat], [AddLoanReceipt], []),
    'cancelLoan' : IDL.Func([IDL.Nat], [CancelLoanReceipt], []),
    'clear' : IDL.Func([], [], ['oneway']),
    'deposit' : IDL.Func([IDL.Nat, IDL.Nat], [DepositReceipt], []),
    'getAllBalances' : IDL.Func([], [IDL.Vec(Balance)], ['query']),
    'getAllPoolBalances' : IDL.Func([], [IDL.Vec(Balance)], ['query']),
    'getBalance' : IDL.Func([IDL.Nat], [IDL.Nat], ['query']),
    'getCanisterICPAddress' : IDL.Func([], [IDL.Vec(IDL.Nat8)], []),
    'getDepositAddress' : IDL.Func([], [IDL.Vec(IDL.Nat8)], []),
    'getLoan' : IDL.Func([IDL.Nat], [IDL.Opt(Loan)], []),
    'getLoanInterestAmount' : IDL.Func([IDL.Nat], [IDL.Nat], []),
    'getLoans' : IDL.Func([], [IDL.Vec(Loan)], []),
    'getPoolBalance' : IDL.Func([], [IDL.Nat], ['query']),
    'payInterest' : IDL.Func([IDL.Nat], [DepositReceipt], []),
    'whoami' : IDL.Func([], [IDL.Principal], ['query']),
    'withdraw' : IDL.Func([IDL.Nat, IDL.Principal], [WithdrawReceipt], []),
    'withdrawFund' : IDL.Func([IDL.Nat, IDL.Principal], [WithdrawReceipt], []),
  });
  return farmLoan;
};
export const init = ({ IDL }) => { return []; };
