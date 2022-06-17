import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";

import M "mo:base/HashMap";

import T "types";

module {

    public class SeniorPool() {

        var share = M.HashMap<Principal, Nat>(10, Principal.equal, Principal.hash);

        public func clear() {
            share := M.HashMap<Principal, Nat>(10, Principal.equal, Principal.hash);
        };

        public func totalCommitted() : Nat{
            var total = 0;
            for ((x, y) in share.entries()) {
                total += y;
            };
            total
        };

        public func entries() : Iter.Iter<(Principal, Nat)> {
            share.entries()
        };

        public func get(user: Principal) : ?Nat {
            share.get(user)
        };

        public func size() : Nat {
            share.size()
        };

        // For development only.
        public func print_balances(){
            for ((x, y) in share.entries()) {
                Debug.print( debug_show("PRINCIPAL: ", x));
                Debug.print( debug_show("Balance: ", y));
            };
        };

        // function that deposit funds.
        public func depositFunds(user: Principal, amount: Nat){
            // check if user already has existing balance
            switch (share.get(user)){
                case (?balance) {
                    share.put(user, balance+amount);
                };
                case(null){
                    share.put(user, amount);
                };
            };
        };

        // Withdraw user funds.
        public func withdrawFunds(user: Principal, amount: Nat) : ?Nat {
            // check if user already has existing balance
            switch (share.get(user)){
                case (?balance) {
                    if (balance>=amount) {
                    if (balance==amount) {
                        share.delete(user);
                    } else {
                        share.put(user, balance-amount);
                    };
                    ?(balance-amount)
                    } else {
                    null
                    }
                };
                case(null){
                    Debug.print("User " # Principal.toText(user) # " has no balance ");
                    null
                };
            };
        };
    };
}
