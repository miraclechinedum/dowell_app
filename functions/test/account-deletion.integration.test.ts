import assert from "node:assert/strict";
import {after, before, beforeEach, test} from "node:test";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {deleteAccountDataForUser} from "../src/account-deletion.js";

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT ?? "demo-dowell";
const app = initializeApp({projectId: process.env.GCLOUD_PROJECT}, "account-deletion-tests");
const db = getFirestore(app);
const authCalls = {revoked: [] as string[], disabled: [] as string[]};
const auth = {
  async revokeRefreshTokens(uid: string) { authCalls.revoked.push(uid); },
  async updateUser(uid: string, value: {disabled: boolean}) {
    assert.equal(value.disabled, true);
    authCalls.disabled.push(uid);
    return {};
  },
};

async function clearCollections() {
  for (const name of ["users", "referrals", "referral_identities", "employee_tasks",
    "bugbucks_transactions", "cash_bonus_transactions", "employee_cashouts",
    "role_requests", "notifications", "audit_logs"]) {
    const snapshot = await db.collection(name).get();
    await Promise.all(snapshot.docs.map((document) => document.ref.delete()));
  }
}

before(() => assert.ok(process.env.FIRESTORE_EMULATOR_HOST));
beforeEach(async () => {
  await clearCollections();
  authCalls.revoked.length = 0;
  authCalls.disabled.length = 0;
});
after(clearCollections);

test("requires an authenticated recently signed-in caller", async () => {
  await assert.rejects(() => deleteAccountDataForUser(db, auth, async () => {}, undefined, 0));
  await assert.rejects(() => deleteAccountDataForUser(
    db, auth, async () => {}, "alice", Math.floor(Date.now() / 1000) - 301));
});

test("soft deletes operational data, preserves history and disables Auth", async () => {
  await db.collection("users").doc("alice").set({status: "active", bugBucks: 100});
  await db.collection("referrals").doc("referral-1").set({
    customerId: "alice", requestId: "request-1", payloadHash: "hash-1",
  });
  await db.collection("referral_identities").doc("identity-1").set({customerId: "alice"});
  await db.collection("employee_tasks").doc("task-1").set({
    employeeId: "alice", requestId: "task-request-1", payloadHash: "task-hash-1",
    imagePaths: ["task_evidence/alice/task-request-1/photo_0.jpg"],
    imageUrls: ["https://example.test/tokenized"],
    images: ["https://example.test/tokenized"],
    status: "approved", isPaid: false, cashBonusAwarded: 25,
  });
  await db.collection("bugbucks_transactions").doc("ledger-1").set({
    userId: "alice", amount: 100, referralId: "referral-1",
  });
  await db.collection("role_requests").doc("role-1").set({userId: "alice"});
  const archived: string[][] = [];

  await deleteAccountDataForUser(
    db, auth, async (paths) => { archived.push(paths); },
    "alice", Math.floor(Date.now() / 1000));
  await deleteAccountDataForUser(
    db, auth, async (paths) => { archived.push(paths); },
    "alice", Math.floor(Date.now() / 1000));

  const profile = await db.collection("users").doc("alice").get();
  assert.equal(profile.exists, true);
  assert.equal(profile.get("isDeleted"), true);
  assert.equal(profile.get("status"), "deleted");
  assert.equal(profile.get("accountDeletionStatus"), "completed");
  assert.equal((await db.collection("referrals").doc("referral-1").get()).get("isDeleted"), true);
  assert.equal((await db.collection("employee_tasks").doc("task-1").get()).get("isDeleted"), true);
  const task = await db.collection("employee_tasks").doc("task-1").get();
  assert.deepEqual(task.get("imagePaths"), ["task_evidence/alice/task-request-1/photo_0.jpg"]);
  assert.deepEqual(task.get("imageUrls"), []);
  assert.deepEqual(task.get("images"), []);
  assert.equal(task.get("deletedOwnerTaskState"), "outstanding_payment");
  assert.equal(task.get("settlementStatus"), "pending");
  assert.equal((await db.collection("role_requests").doc("role-1").get()).get("isDeleted"), true);
  assert.equal((await db.collection("referral_identities").doc("identity-1").get()).exists, true);
  assert.equal((await db.collection("bugbucks_transactions").doc("ledger-1").get()).get("amount"), 100);
  assert.deepEqual(authCalls.revoked, ["alice", "alice"]);
  assert.deepEqual(authCalls.disabled, ["alice", "alice"]);
  assert.equal((await db.collection("audit_logs").get()).size, 1);
  assert.deepEqual(archived, [
    ["task_evidence/alice/task-request-1/photo_0.jpg"],
    ["task_evidence/alice/task-request-1/photo_0.jpg"],
  ]);
});

test("records a recoverable failed state when Auth disabling fails", async () => {
  await db.collection("users").doc("alice").set({status: "active"});
  const failingAuth = {
    async revokeRefreshTokens() {},
    async updateUser() { throw new Error("simulated Auth failure"); },
  };
  await assert.rejects(() => deleteAccountDataForUser(
    db, failingAuth, async () => {}, "alice", Math.floor(Date.now() / 1000)));
  const profile = await db.collection("users").doc("alice").get();
  assert.equal(profile.get("isDeleted"), true);
  assert.equal(profile.get("accountDeletionStatus"), "failed");
});
