import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";

import Hash "mo:base/Hash";
import M "mo:base/HashMap";

import T "types";

module {

    //Keeps track of loans and amount creditors provided for each loan.
    public class LoansBook() {

        var book = M.HashMap<Principal, M.HashMap<Nat, Nat>>(10, Principal.equal, Principal.hash);

        public func get(user: Principal) : ?M.HashMap<Nat, Nat> {
            book.get(user);
        };

        public func put(user: Principal, userBalances: M.HashMap<Nat, Nat>) {
            book.put(user, userBalances);
        };

        public func entries() : Iter.Iter<(Principal,M.HashMap<Nat, Nat>)> {
            book.entries()
        };

        public func size() : Nat {
            book.size()
        };

        // For development only.
        public func print_balances(){
            for ((x, y) in book.entries()) {
                Debug.print( debug_show("PRINCIPAL: ", x));
                for ((key: Nat, value: Nat) in y.entries()) {
                    Debug.print( debug_show("Balance: Loan: ", key, " amount: ",value));
                };
            };
        };

        public func clear() {
            book := M.HashMap<Principal, M.HashMap<Nat, Nat>>(10, Principal.equal, Principal.hash);
        };

        // function that adds loans to book. Book keeps track of users deposits.
        public func addLoan(user: Principal, loanID: Nat, amount: Nat){
            switch (book.get(user)) {
                case (?loan_balance) {
                    // check if user already has existing balance for this loan
                    switch (loan_balance.get(loanID)){
                        case (?balance) {
                            loan_balance.put(loanID, balance+amount);
                        };
                        case(null){
                            loan_balance.put(loanID, amount);
                        };
                    };
                };
                case (null) {
                    // user didn't exist
                    var x1 = M.HashMap<Nat, Nat>(10, Nat.equal, Hash.hash);
                    x1.put(loanID,amount);
                    book.put(user,x1);
                };
            };
        };

        // return the new balance.
        public func removeLoans(user: Principal, loanID: Nat, amount: Nat) : ?Nat {
            switch (book.get(user)) {
                case (?loan_balance) {
                    // check if user already has existing balance for this loan
                    switch (loan_balance.get(loanID)){
                        case (?balance) {
                          if (balance>=amount) {
                            if (balance==amount) {
                              loan_balance.delete(loanID);
                            } else {
                              loan_balance.put(loanID, balance-amount);
                            };
                            ?(balance-amount)
                          } else {
                            null
                            }
                        };
                        case(null){
                            Debug.print("User " # Principal.toText(user) # " has no balance of loan " # Nat.toText(loanID));
                            null
                        };
                    };
                };
                case (null) {
                    // user didn't exist
                    Debug.print("User " # Principal.toText(user) # " doesn't exist in book, cannot remove loans.");
                    null
                };
            };
        };

        // Return true if a user has at least amount loans in the book, false otherwise.
        public func hasEnoughBalance(user: Principal, loanID: Nat, amount: Nat) : Bool {
            switch (book.get(user)) {
                case (?balances) {
                    switch(balances.get(loanID)) {
                        case (?balance) return balance >= amount;
                        case null return false;
                    }
                };
                case null return false;
            };
        }
    }
}
