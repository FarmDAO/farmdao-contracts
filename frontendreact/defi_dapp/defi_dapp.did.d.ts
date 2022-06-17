import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';

export type AddLoanErr = { 'LoansBookFull' : null } |
  { 'InvalidLoan' : null };
export type AddLoanReceipt = { 'Ok' : [] | [Loan] } |
  { 'Err' : AddLoanErr };
export interface Balance {
  'owner' : Principal,
  'loanId' : bigint,
  'amount' : bigint,
}
export type CancelLoanErr = { 'NotAllowed' : null } |
  { 'NotExistingLoan' : null };
export type CancelLoanReceipt = { 'Ok' : bigint } |
  { 'Err' : CancelLoanErr };
export type DepositErr = { 'DepositError' : null } |
  { 'TransferFailure' : null } |
  { 'BalanceLow' : null };
export type DepositReceipt = { 'Ok' : bigint } |
  { 'Err' : DepositErr };
export interface Loan {
  'id' : bigint,
  'startTime' : Time,
  'status' : LoanStatus,
  'interest' : bigint,
  'owner' : Principal,
  'juniorAmount' : bigint,
  'seniorAmount' : bigint,
}
export type LoanStatus = { 'initiated' : null } |
  { 'approved' : null } |
  { 'repayed' : null } |
  { 'raised' : null } |
  { 'defaulted' : null };
export type Time = bigint;
export type WithdrawErr = { 'TransferFailure' : null } |
  { 'BalanceLow' : null };
export type WithdrawReceipt = { 'Ok' : bigint } |
  { 'Err' : WithdrawErr };
export interface farmLoan {
  'addLoan' : ActorMethod<[bigint, bigint, bigint], AddLoanReceipt>,
  'cancelLoan' : ActorMethod<[bigint], CancelLoanReceipt>,
  'clear' : ActorMethod<[], undefined>,
  'deposit' : ActorMethod<[bigint, bigint], DepositReceipt>,
  'getAllBalances' : ActorMethod<[], Array<Balance>>,
  'getAllPoolBalances' : ActorMethod<[], Array<Balance>>,
  'getBalance' : ActorMethod<[bigint], bigint>,
  'getCanisterICPAddress' : ActorMethod<[], Array<number>>,
  'getDepositAddress' : ActorMethod<[], Array<number>>,
  'getLoan' : ActorMethod<[bigint], [] | [Loan]>,
  'getLoanInterestAmount' : ActorMethod<[bigint], bigint>,
  'getLoans' : ActorMethod<[], Array<Loan>>,
  'getPoolBalance' : ActorMethod<[], bigint>,
  'payInterest' : ActorMethod<[bigint], DepositReceipt>,
  'whoami' : ActorMethod<[], Principal>,
  'withdraw' : ActorMethod<[bigint, Principal], WithdrawReceipt>,
  'withdrawFund' : ActorMethod<[bigint, Principal], WithdrawReceipt>,
}
export interface _SERVICE extends farmLoan {}
