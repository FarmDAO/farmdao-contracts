<script>
  import { onMount } from "svelte";
  import { Principal } from "@dfinity/principal";
  import { auth, plugWallet, anonymous } from "../store/auth";
  import {
    canisters,
    loans,
    userBalances,
    createCanisterActor,
  } from "../store/store";
  import { AuthClient } from "@dfinity/auth-client";
  import { FontAwesomeIcon } from "fontawesome-svelte";
  import {
    toHexString,
    hexToBytes,
    principalToAccountDefaultIdentifier,
  } from "../utils/helpers";
  import { HttpAgent } from "@dfinity/agent/lib/cjs/agent";
  import { idlFactory as backendIDL } from "../../declarations/defi_dapp/defi_dapp.did.js";
  import { idlFactory as ledgerIDL } from "../../declarations/ledger/ledger.did.js";

  let depositAddressBlob;
  let iiPrincipal = "";
  let authType = "anonymous";

  let backendActor;
  let ledgerActor;
  let authClient;

  // Global variables
  const host =
    process.env.DFX_NETWORK === "local" ? `http://localhost:8000` : "ic0.app";

  const newLoan = {
    amount: 0,
  };

  const newDeposit = {
    loan_id: 0,
    amount: 0,
  };

  let loan_id = 0;

  plugWallet.subscribe((value) => {
    if (value.plugActor) {
      console.log("Plug connected, plug actor");
      backendActor = value.plugActor;
    }
  });

  auth.subscribe(async (value) => {
    if (value.loggedIn) {
      backendActor = value.actor;
      authClient = await AuthClient.create();
    }
  });

  onMount(async () => {
    // Use II as actor
    if ($auth.loggedIn) {
      console.log("Using II for DEX actor");
      authType = "II";

      // II must display principle, since it is unique.
      iiPrincipal = $auth.principal;

      // TODO: When using II, display a note on how to deposit.
      // e.g.
      //
      // To transfer tokens, use the DIP canister to transfer tokens to <iiPrincipal>, and the balance will be reflected here.
      // To transfer ICP, use the ledger to transfer ICP to <depositAddress>, and the balance will be reflected here.
      //
      // This can replace the COPY we have at the bottom, as this is not needed when using Plug

      // Create canister actors
      const authClient = await AuthClient.create();
      const identity = authClient.getIdentity();
      const agent = new HttpAgent({ identity, host });

      if (process.env.DFX_NETWORK === "local") agent.fetchRootKey();

      backendActor = createCanisterActor(
        agent,
        backendIDL,
        process.env.DEFI_DAPP_CANISTER_ID
      );
      ledgerActor = createCanisterActor(
        agent,
        ledgerIDL,
        process.env.LEDGER_CANISTER_ID
      );

      let ledgerBalance = 0;

      // // Fetch initial balances
      // const goldenBalance = await goldenActor.balanceOf($auth.principal);
      // const akitaBalance = await akitaActor.balanceOf($auth.principal);
      // let ledgerBalance = 0;

      depositAddressBlob = await backendActor.getDepositAddress();
      const approved = await ledgerActor.account_balance({
        account: hexToBytes(principalToAccountDefaultIdentifier(iiPrincipal)),
      });
      if (approved.e8s) {
        ledgerBalance = approved.e8s;
      }
    }

    console.log("You are (deposit): ", toHexString(depositAddressBlob));
  });

  async function createLoanRequest(amount) {
    if (amount <= 10000000)
      console.log("Amount must be greater than: 10,000,000");
    const svnty_ratio = (amount * 70) / 100;
    const thrty_ratio = amount - svnty_ratio;

    if (svnty_ratio % 1 != 0) {
      console.log("Please use round figures");
    } else {
      await backendActor.addLoan(thrty_ratio, svnty_ratio, 20);
      console.log("Done!");
    }
  }

  async function getLoans() {
    const loans = await backendActor.getLoans();
    userBalances.set([...loans]);
    console.log(loans);
  }

  async function depositIntoPool(loan_id, amount) {
    if (amount % 1 != 0) {
      console.log("Please use round figures");
    } else {
      await backendActor.deposit(loan_id, amount);
      console.log("Deposited");
    }
  }
  async function getPoolBalance(id) {
    const balance = await backendActor.getPoolBalance(id);

    console.log(balance);
    // console.log(`Pool ${id} balance = ${balance}`);
  }
</script>

<div>
  <p>Hello from Loans</p>
  <input class="input-style" bind:value={newLoan.amount} type="number" />
  <button
    class="btn-accept"
    on:click={createLoanRequest(newLoan.amount)}
    title="Create Loan Request">Create A Loan!</button
  >
  <button class="btn-accept" on:click={getLoans} title="Create Loan Request"
    >Show Loans!</button
  >

  <p>Deposit into a pool</p>
  <input class="input-style" bind:value={newDeposit.loan_id} type="number" />
  <input class="input-style" bind:value={newDeposit.amount} type="number" />
  <button
    class="btn-accept"
    on:click={depositIntoPool(newDeposit.loan_id, newDeposit.amount)}
    title="Deposit into a pool">Deposit into a Pool</button
  >

  <p>Get Pool Balance</p>
  <input class="input-style" bind:value={loan_id} type="number" />
  <button
    class="btn-accept"
    on:click={getPoolBalance(loan_id)}
    title="Get pool balance">Get pool balance</button
  >
</div>
