import assert from "node:assert/strict";
import {after, beforeEach, test} from "node:test";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {
  listAccountDeletionCandidates,
  reconcileAccountDeletionForUser,
  settleDeletedEmployeeTask,
} from "../src/account-reconciliation.js";

const app = initializeApp({projectId: "demo-dowell"}, "reconciliation-tests");
const db = getFirestore(app);
const auth = {
  disabled: false,
  async getUser() { return {disabled: this.disabled}; },
  async revokeRefreshTokens() {},
  async updateUser(_uid: string, value: {disabled: boolean}) {
    this.disabled = value.disabled;
    return {};
  },
};

async function clear() {
  for (const name of ["users", "employee_tasks", "cash_bonus_transactions", "audit_logs"]) {
    const snapshot = await db.collection(name).get();
    await Promise.all(snapshot.docs.map((document) => document.ref.delete()));
  }
}

beforeEach(async () => { await clear(); auth.disabled = false; });
after(clear);

test("finds and completes a pending deleted account idempotently", async () => {
  await db.collection("users").doc("employee").set({
    status: "deleted", isDeleted: true, accountDeletionStatus: "pending",
  });
  assert.equal((await listAccountDeletionCandidates(db)).length, 1);
  await reconcileAccountDeletionForUser(db, auth, async () => {}, "employee", "admin");
  assert.equal(auth.disabled, true);
  assert.equal((await db.collection("users").doc("employee").get())
    .get("accountDeletionStatus"), "completed");
  await reconcileAccountDeletionForUser(db, auth, async () => {}, "employee", "admin");
  assert.equal((await db.collection("users").doc("employee").get())
    .get("accountDeletionStatus"), "completed");
});

test("settles an archived obligation once without restoring user balance", async () => {
  await db.collection("employee_tasks").doc("task").set({
    employeeId: "employee", status: "approved", isDeleted: true,
    ownerAccountDeleted: true, isPaid: false, paidOut: false, cashBonusAwarded: 40,
  });
  const first = await settleDeletedEmployeeTask(db, "task", "admin");
  const retry = await settleDeletedEmployeeTask(db, "task", "admin");
  assert.deepEqual(retry, first);
  assert.equal((await db.collection("cash_bonus_transactions").get()).size, 1);
  assert.equal((await db.collection("employee_tasks").doc("task").get()).get("isPaid"), true);
  assert.equal((await db.collection("users").doc("employee").get()).exists, false);
});
