<script>
  import { onMount } from "svelte";
  import { Principal } from "@dfinity/principal";
  import { auth, plugWallet, anonymous } from "../store/auth";
  import {
    canisters,
    loans,
    loanDetils,
    loanCreation,
    loanStatus,
    juniorDeposit,
    seniorDeposit,
    juniorPoolBalance,
    seniorPoolBalance,
    seniorWithdrawal,
    loanWithdrawal,
    loanRepay,
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
  let ledgerBalance = 0;
  const interestAmount = 20;

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

      console.log("Approved: ", approved);
    }

    console.log("You are (deposit): ", toHexString(depositAddressBlob));
    console.log(await backendActor.getAllPoolBalances());

    // console.log(
    //   "ledgerActor Transfer: ",
    //   await ledgerActor.transfer({
    //     to: depositAddressBlob,
    //     fee: { e8s: 10000n },
    //     from_subaccount: [],
    //     created_at_time: [],
    //     memo: 20000n,
    //     amount: { e8s: 200000n },
    //   })
    // );
    // console.log(depositAddressBlob);
    // const approved = await ledgerActor.account_balance({
    //   account: depositAddressBlob,
    // });

    // console.log("Balance after transfer: ", approved.e8s);
    // console.log(ledgerBalance);
    // console.log(integer(1000 + "n"));
    const intrest = await backendActor.getLoanInterestAmount(BigInt(1));
    console.log("Loan interest (10): ", Number(intrest));
    console.log("Loan interest (10, bigint): ", intrest);
  });

  async function createLoanRequest(amount) {
    if (amount <= 10000000)
      console.log("Amount must be greater than: 10,000,000 icp");
    loanCreation.set("Amount must be greater than: 10,000,000 icp");
    const svnty_ratio = (amount * 70) / 100;
    const thrty_ratio = amount - svnty_ratio;

    if (svnty_ratio % 1 != 0) {
      console.log("Please use round figures");
      loanCreation.set("Please use round figures");
    } else {
      await backendActor.addLoan(thrty_ratio, svnty_ratio, interestAmount);
      loanCreation.set("Loan creation done, click show loans to see details");
      console.log("Done!");
    }
  }

  async function getLoans() {
    const loansList = await backendActor.getLoans();
    loans.set([...loansList]);
    console.log($loans);
  }

  async function getLoanStatus(id) {
    const loan = await backendActor.getLoan(BigInt(id));
    const status = Object.keys(loan[0].status)[0];
    loanStatus.set(status);

    console.log(`Loan ${id} status: `, status);
    return status;
  }

  async function depositIntoJuniorPool(loan_id, amount) {
    if (amount % 1 != 0) {
      juniorDeposit.set("Please use round figures");
      console.log("Please use round figures");
    } else {
      juniorDeposit.set("Please wait...");
      console.log("Transfering tokens to depositBlob");
      const transfer = await ledgerActor.transfer({
        to: depositAddressBlob,
        fee: { e8s: BigInt(10000) },
        memo: BigInt(loan_id),
        from_subaccount: [],
        created_at_time: [],
        amount: { e8s: BigInt(amount) },
      });
      console.log("transfer done: ", transfer);
      console.log("----------------------------------------------");
      console.log("Making deposit");
      const makeDeposit = await backendActor.deposit(
        BigInt(loan_id),
        BigInt(amount)
      );
      juniorDeposit.set(`Deposited ${amount} icp into pool ${loan_id}`);
      console.log("Deposited: ", makeDeposit);
    }
  }

  async function depositIntoSeniorPool(amount) {
    console.log("Transfering tokens to depositBlob");
    seniorDeposit.set("Please wait...");
    const transfer = await ledgerActor.transfer({
      to: depositAddressBlob,
      fee: { e8s: BigInt(10000) },
      memo: BigInt(amount),
      from_subaccount: [],
      created_at_time: [],
      amount: { e8s: BigInt(amount) },
    });
    console.log("transfer done: ", transfer);
    console.log("----------------------------------------------");
    console.log("Making deposit into senior pool");
    const makeDeposit = await backendActor.deposit(0, BigInt(amount));
    seniorDeposit.set(`Deposited ${amount} icp into senior pool!`);
    console.log("Deposited into senior pool: ", makeDeposit);
  }

  async function getBalance(id) {
    const Balance = await backendActor.getBalance(BigInt(id));
    juniorPoolBalance.set(
      `Your junior pool ${id} balance = ${Number(Balance)} icp`
    );
    seniorPoolBalance.set("");
    console.log(`Pool ${id} balance = `, Balance);
  }

  async function getPoolBalance() {
    const poolBalance = await backendActor.getPoolBalance();
    seniorPoolBalance.set(
      `Your senior pool balance = ${Number(poolBalance)} icp`
    );
    juniorPoolBalance.set("");
    console.log(`Senior Pool balance = `, poolBalance);
  }

  async function getPoolDetails(id) {
    const poolDetails = await backendActor.getLoan(BigInt(id));
    loanDetils.set([...poolDetails]);
    console.log(`Loan ${id} details: `, poolDetails[0]);
  }

  async function withdrawFromPool(loan_id) {
    seniorWithdrawal.set("Please wait...");
    const principal = iiPrincipal;

    const makeWithdrawal = await backendActor.withdraw(loan_id, principal);
    console.log(
      `Withdrawing your contribution from pool ${loan_id}`,
      makeWithdrawal
    );
    seniorWithdrawal.set(
      `Successfully withdrew ${makeWithdrawal.Ok.toString().replace(
        /\B(?=(\d{3})+(?!\d))/g,
        ","
      )} icp from pool ${loan_id}`
    );
  }

  async function withdrawFunds(loan_id) {
    const principal = iiPrincipal;
    loanWithdrawal.set("Please wait...");

    if ((await getLoanStatus(loan_id)) == "approved") {
      const makeWithdrawRequest = await backendActor.withdrawFund(
        BigInt(loan_id),
        principal
      );
      loanWithdrawal.set(`Loan ${loan_id} withdrawal is successful`);
      console.log("Withdrawal: ", makeWithdrawRequest);
    } else if ((await getLoanStatus(loan_id)) == "raised") {
      loanWithdrawal.set(`Funds for loan ${loan_id} already withdrawn.`);
    } else if ((await getLoanStatus(loan_id)) == "cancelled") {
      loanWithdrawal.set(`Loan ${loan_id} was cancelled`);
    } else {
      console.log(
        `Loan pool ${loan_id} hasn't been approved, wait until it has been approved.`
      );
      loanWithdrawal.set(
        `Loan pool ${loan_id} hasn't been approved, wait until it has been approved.`
      );
    }
  }

  async function payLoanWithInterest(loan_id) {
    loanRepay.set("Please wait...");
    const loanDetails = await backendActor.getLoan(BigInt(loan_id));
    const juniorAmount = Number(loanDetails[0].juniorAmount);
    const seniorAmount = Number(loanDetails[0].seniorAmount);
    const amount_borrowed = juniorAmount + seniorAmount;

    const amount_to_pay =
      amount_borrowed + (interestAmount * amount_borrowed) / 100;
    loanRepay.set(
      `Amount to repay is ${amount_to_pay
        .toString()
        .replace(/\B(?=(\d{3})+(?!\d))/g, ",")} icp`
    );
    const availableBalance = await ledgerActor.account_balance({
      account: hexToBytes(principalToAccountDefaultIdentifier(iiPrincipal)),
    });
    if (availableBalance.e8s > amount_to_pay) {
      console.log("Transfering tokens to deposit address");
      const transfer = await ledgerActor.transfer({
        to: depositAddressBlob,
        fee: { e8s: BigInt(10000) },
        memo: BigInt(amount_to_pay),
        from_subaccount: [],
        created_at_time: [],
        amount: { e8s: BigInt(amount_to_pay) },
      });
      console.log("transfer done: ", transfer);
      console.log("----------------------------------------------");
      console.log(
        `Making payment (with interest of ${interestAmount} for loan ${loan_id}`
      );
      const makePayment = await backendActor.payInterest(loan_id);
      loanRepay.set(`loan ${loan_id} repaid in full!.`);
      console.log("Payment status: ", makePayment);
    } else {
      loanRepay.set(
        `Your balance is too low to repay the loan with interest (${amount_to_pay
          .toString()
          .replace(/\B(?=(\d{3})+(?!\d))/g, ",")} icp)`
      );
      console.log(`ummm check ${availableBalance.e8s} and ${amount_to_pay}`);
    }
  }
</script>

<div>
  <br />
  <p>Create Loan Pool/Show Existing Loans</p>
  <input class="input-style" bind:value={newLoan.amount} type="number" />
  <button
    class="btn-accept"
    on:click={createLoanRequest(newLoan.amount)}
    title="Create Loan Request">Create!</button
  >
  <button class="btn-accept" on:click={getLoans} title="Create Loan Request"
    >Show Loans Pools!</button
  >
  <p>{$loanCreation}</p>
  <table class="loans-table">
    <thead>
      <th>Owner</th>
      <th>Loan Id</th>
      <th>Junior Amount</th>
      <th>Senior Amount</th>
      <th>Status</th>
    </thead>
    <tbody>
      {#each $loans as loan}
        <tr>
          <td>
            {loan.owner}
          </td>
          <td>
            {loan.id}
          </td>
          <td>
            {loan.juniorAmount}
          </td>
          <td>
            {loan.seniorAmount}
          </td>
          <td>
            {Object.keys(loan.status)}
          </td>
        </tr>
      {/each}
    </tbody>
  </table>

  <p>Get Loan Pool status</p>
  <input class="input-style" bind:value={loan_id} type="number" />
  <button
    class="btn-accept"
    on:click={getLoanStatus(loan_id)}
    title="Get Loan Pool Status">Status</button
  >
  {$loanStatus}

  <p>Deposit into a pool (junior)</p>
  <input class="input-style" bind:value={newDeposit.loan_id} type="number" />
  <input class="input-style" bind:value={newDeposit.amount} type="number" />
  <button
    class="btn-accept"
    on:click={depositIntoJuniorPool(newDeposit.loan_id, newDeposit.amount)}
    title="Deposit into Loan Pool">Deposit</button
  >
  {$juniorDeposit.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")}

  <p>Deposit into a pool (senior)</p>
  <input class="input-style" bind:value={newDeposit.amount} type="number" />
  <button
    class="btn-accept"
    on:click={depositIntoSeniorPool(newDeposit.amount)}
    title="Deposit into Loan Pool">Deposit</button
  >
  {$seniorDeposit.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")}

  <p>Get Pool Balance/Details</p>
  <input class="input-style" bind:value={loan_id} type="number" />
  <button
    class="btn-accept"
    on:click={getBalance(loan_id)}
    title="Get Loan Pool Balance">Junior pool Balance</button
  >
  <button
    class="btn-accept"
    on:click={getPoolDetails(loan_id)}
    title="Get Loan Pool Details">Pool Details</button
  >
  <button
    class="btn-accept"
    on:click={getPoolBalance(loan_id)}
    title="Get Loan Pool Balance">Senior pool Balance</button
  >{$juniorPoolBalance.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")}
  {$seniorPoolBalance.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")}
  <table class="loans-table">
    <thead>
      <th>Owner</th>
      <th>Loan Id</th>
      <th>Junior Amount</th>
      <th>Senior Amount</th>
      <th>Status</th>
    </thead>
    <tbody>
      {#each $loanDetils as loan}
        <tr>
          <td>
            {loan.owner}
          </td>
          <td>
            {loan.id}
          </td>
          <td>
            {loan.juniorAmount}
          </td>
          <td>
            {loan.seniorAmount}
          </td>
          <td>
            {Object.keys(loan.status)}
          </td>
        </tr>
      {/each}
    </tbody>
  </table>

  <p>Withdraw earnings from Senior pool</p>
  <input class="input-style" bind:value={loan_id} type="number" />
  <button
    class="btn-accept"
    on:click={withdrawFromPool(loan_id)}
    title="Withdraw from pool">Withdraw</button
  >
  {$seniorWithdrawal}

  <p>Withdraw Funds From Pool</p>
  <input class="input-style" bind:value={loan_id} type="number" />
  <button
    class="btn-accept"
    on:click={withdrawFunds(loan_id)}
    title="Get Loan Pool Balance">Withdraw funds</button
  >
  {$loanWithdrawal}

  <p>Repay Loan</p>
  <input class="input-style" bind:value={loan_id} type="number" />
  <button
    class="btn-accept"
    on:click={payLoanWithInterest(loan_id)}
    title="Repay loan">Repay Loan</button
  >
  {$loanRepay}
  <br />
</div>

<style>
  table,
  th,
  td {
    border: 1px solid;
    border-collapse: collapse;
    margin-bottom: 10px;
  }

  table {
    border: 1px solid #005187;
    background-color: #000000;
    width: 100%;
    text-align: left;
    margin-top: 20px;
    border-collapse: collapse;
  }
  table td,
  table th {
    border: 1px solid #aaaaaa;
    padding: 3px 2px;
  }
  table tbody td {
    font-size: 13px;
  }
  table tr:nth-child(even) {
    background: #fbfbfb;
    color: #000000;
  }
  table thead {
    background: #1c6ea4;
    background: -moz-linear-gradient(
      top,
      #5592bb 0%,
      #327cad 66%,
      #1c6ea4 100%
    );
    background: -webkit-linear-gradient(
      top,
      #5592bb 0%,
      #327cad 66%,
      #1c6ea4 100%
    );
    background: linear-gradient(
      to bottom,
      #5592bb 0%,
      #327cad 66%,
      #1c6ea4 100%
    );
    border-bottom: 2px solid #444444;
  }
  table thead th {
    font-size: 15px;
    font-weight: bold;
    color: #ffffff;
    border-left: 2px solid #d0e4f5;
  }
  table thead th:first-child {
    border-left: none;
  }
</style>
