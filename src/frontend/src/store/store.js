import { Actor } from "@dfinity/agent";
import { writable } from "svelte/store";

export const canisters = writable([
  {
    symbol: "AKI",
    canisterName: "AkitaDIP20",
    canisterId: process.env.AKITADIP20_CANISTER_ID,
  },
  {
    symbol: "GLD",
    canisterName: "GoldenDIP20",
    canisterId: process.env.GOLDENDIP20_CANISTER_ID,
  },
  {
    symbol: "ICP",
    canisterName: "ICP",
    canisterId: process.env.LEDGER_CANISTER_ID,
  },
]);

export const canisterActors = writable([]);

export const userBalances = writable([]);

export const loanCreation = writable("");

export const loans = writable([]);

export const loanDetils = writable([]);

export const loanStatus = writable("");

export const juniorDeposit = writable("");

export const seniorDeposit = writable("");

export const juniorPoolBalance = writable("");

export const seniorPoolBalance = writable("");

export const seniorWithdrawal = writable("");

export const loanWithdrawal = writable("");

export const loanRepay = writable("");

export const createCanisterActor = (agent, idl, canisterId) => {
  return Actor.createActor(idl, {
    agent,
    canisterId,
  });
};
