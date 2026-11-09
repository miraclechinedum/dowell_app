import assert from "node:assert/strict";
import {after, beforeEach, describe, it} from "node:test";
import {deleteApp, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {adjustUserBalanceForAdmin, reviewEmployeeTaskForAdmin} from "../src/admin-finance.js";
import {submitEmployeeTaskForUser} from "../src/employee-tasks.js";

// Runs against the Firestore emulator (demo-dowell); no production data.
const app = initializeApp({projectId: "demo-dowell"}, "admin-finance-tests");
const db = getFirestore(app);
const ADMIN = "client-admin";

async function clear() {
  for (const name of ["users", "employee_tasks", "cash_bonus_transactions", "bugbucks_transactions", "audit_logs", "app_settings"]) {
    const snapshot = await db.collection(name).get();
    await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
  }
}

async function ledger(name: string, field: string, value: string) {
  return (await db.collection(name).where(field, "==", value).get()).docs;
}

const rejectsWith = (code: string) => (error: HttpsError) => error.code === code;

after(async () => { await clear(); await deleteApp(app); });

describe("reviewEmployeeTask backend", () => {
  const approve = (extra: Record<string, unknown> = {}) =>
    reviewEmployeeTaskForAdmin(db, ADMIN, {taskId: "t1", decision: "approve", ...extra});
  const setBonus = (value: unknown) => db.doc("app_settings/reward_settings").set({employee_cash_bonus: value});

  beforeEach(async () => {
    await clear();
    await setBonus(25);
    await db.doc("users/emp").set({role: "employee", status: "active", cashBonusBalance: 5, pendingTasks: 1, totalTasks: 1});
    await db.doc("employee_tasks/t1").set({employeeId: "emp", status: "pending", isDeleted: false});
  });

  // Task, balance, counters, ledger and audit are all untouched.
  async function unchanged() {
    const [task, user, entries, audit] = await Promise.all([
      db.doc("employee_tasks/t1").get(), db.doc("users/emp").get(),
      ledger("cash_bonus_transactions", "taskId", "t1"), db.doc("audit_logs/task_review_t1").get(),
    ]);
    assert.deepEqual([task.get("status"), task.get("cashBonusAwarded"), user.get("cashBonusBalance"),
      user.get("pendingTasks"), user.get("totalTasks"), entries.length, audit.exists],
    ["pending", undefined, 5, 1, 1, 0, false]);
  }

  it("awards the configured bonus, records its source, and treats a repeat as a no-op", async () => {
    const first = await approve({expectedBonusAmount: 25});
    await setBonus(40); // A later settings change must not affect an already-approved task.
    const second = await approve();
    assert.deepEqual([first.alreadyReviewed, first.cashBonusAwarded, first.balanceAfter], [false, 25, 30]);
    assert.deepEqual([second.alreadyReviewed, second.cashBonusAwarded], [true, 25]);
    const user = await db.doc("users/emp").get();
    assert.deepEqual([user.get("cashBonusBalance"), user.get("pendingTasks"), user.get("totalTasks")], [30, 0, 1]);
    const entries = await ledger("cash_bonus_transactions", "taskId", "t1");
    assert.equal(entries.length, 1);
    assert.deepEqual([entries[0].id, entries[0].get("balanceBefore"), entries[0].get("balanceAfter"), entries[0].get("bonusSource")],
      ["task_bonus_t1", 5, 30, "app_settings/reward_settings.employee_cash_bonus"]);
    const audit = await db.doc("audit_logs/task_review_t1").get();
    assert.deepEqual([audit.get("action"), audit.get("amount"), audit.get("balanceAfter")], ["TASK_APPROVED", 25, 30]);
  });

  it("accepts the boundary bonuses 0.01 and 1000 exactly", async () => {
    for (const [bonus, balanceAfter] of [[0.01, 5.01], [1000, 1005]] as const) {
      await clear();
      await setBonus(bonus);
      await db.doc("users/emp").set({role: "employee", status: "active", cashBonusBalance: 5, pendingTasks: 1, totalTasks: 1});
      await db.doc("employee_tasks/t1").set({employeeId: "emp", status: "pending", isDeleted: false});
      const result = await approve({expectedBonusAmount: bonus});
      assert.deepEqual([result.cashBonusAwarded, result.balanceAfter], [bonus, balanceAfter]);
      const entry = await db.doc("cash_bonus_transactions/task_bonus_t1").get();
      assert.deepEqual([entry.get("amount"), entry.get("balanceAfter")], [bonus, balanceAfter]);
      assert.equal((await db.doc("users/emp").get()).get("cashBonusBalance"), balanceAfter);
    }
  });

  it("rejects 1000.01 server-side without any writes", async () => {
    await setBonus(1000.01);
    await assert.rejects(() => approve(), (error: HttpsError) => error.code === "failed-precondition" &&
      (error.details as {reason?: string}).reason === "bonus-configuration-invalid");
    await unchanged();
  });

  it("never accepts a client-supplied bonus amount", async () => {
    await assert.rejects(() => approve({bonusAmount: 25}), rejectsWith("invalid-argument"));
    await assert.rejects(() => approve({bonusAmount: 9999}), rejectsWith("invalid-argument"));
    await unchanged();
  });

  it("fails safely when the bonus configuration is missing or invalid", async () => {
    await db.doc("app_settings/reward_settings").delete();
    await assert.rejects(() => approve(), rejectsWith("failed-precondition"));
    for (const value of ["25", 0, -5, 5000, 1000.01, 2.345, 0.001, null]) {
      await setBonus(value);
      await assert.rejects(() => approve(), rejectsWith("failed-precondition"));
    }
    await unchanged();
  });

  it("refuses when the configured bonus differs from the amount shown to the admin", async () => {
    await assert.rejects(() => approve({expectedBonusAmount: 20}),
      (error: HttpsError) => error.code === "failed-precondition" &&
        (error.details as {reason?: string}).reason === "bonus-changed");
    await unchanged();
  });

  it("credits once and decrements the counter once under concurrent approvals", async () => {
    const results = await Promise.allSettled([1, 2, 3].map(() => approve()));
    assert.ok(results.every((result) => result.status === "fulfilled"));
    const user = await db.doc("users/emp").get();
    assert.deepEqual([user.get("cashBonusBalance"), user.get("pendingTasks")], [30, 0]);
    assert.equal((await ledger("cash_bonus_transactions", "taskId", "t1")).length, 1);
  });

  it("refuses a conflicting second review", async () => {
    await approve();
    await assert.rejects(() => reviewEmployeeTaskForAdmin(db, ADMIN, {taskId: "t1", decision: "reject"}),
      rejectsWith("failed-precondition"));
    assert.equal((await db.doc("users/emp").get()).get("cashBonusBalance"), 30);
  });

  it("rejects without crediting, and refuses tasks owned by closed accounts", async () => {
    await reviewEmployeeTaskForAdmin(db, ADMIN, {taskId: "t1", decision: "reject", notes: "No evidence"});
    const user = await db.doc("users/emp").get();
    assert.deepEqual([user.get("cashBonusBalance"), user.get("pendingTasks")], [5, 0]);
    assert.equal((await ledger("cash_bonus_transactions", "taskId", "t1")).length, 0);
    await db.doc("users/gone").set({status: "deleted", isDeleted: true});
    await db.doc("employee_tasks/t2").set({employeeId: "gone", status: "pending"});
    await assert.rejects(() => reviewEmployeeTaskForAdmin(db, ADMIN, {taskId: "t2", decision: "approve"}),
      rejectsWith("failed-precondition"));
    assert.equal((await ledger("cash_bonus_transactions", "taskId", "t2")).length, 0);
  });
});

describe("task counters stay consistent across submission and review", () => {
  const employee = {uid: "emp-c", token: {employee: true, email: "e@example.test"}};
  const task = (requestId: string) => ({
    requestId, title: "Inspection", description: "Inspect", customerName: "Customer",
    customerEmail: "c@example.test", customerPhone: "5551234567", customerAddress: "", notes: "",
    imageUrls: ["https://storage.example/e.jpg"], imagePaths: [`task_evidence/emp-c/${requestId}/photo_0.jpg`],
    amount: 0, type: "inspection", category: "service", priority: "medium",
  });

  beforeEach(async () => {
    await clear();
    await db.doc("app_settings/reward_settings").set({employee_cash_bonus: 10});
    await db.doc("users/emp-c").set({role: "employee", status: "active", pendingTasks: 0, totalTasks: 0});
  });

  async function assertCountersMatchRecords() {
    const [user, tasks] = await Promise.all([
      db.doc("users/emp-c").get(),
      db.collection("employee_tasks").where("employeeId", "==", "emp-c").get(),
    ]);
    const pending = tasks.docs.filter((doc) => doc.get("status") === "pending").length;
    assert.deepEqual([user.get("totalTasks"), user.get("pendingTasks")], [tasks.size, pending],
      "stored counters match the task records");
    return {total: tasks.size, pending};
  }

  it("counts each task once despite concurrent submissions and retries, and reviews decrement once", async () => {
    const ids = ["counter_request_aaaa01", "counter_request_bbbb02", "counter_request_cccc03"];
    // Each request is sent twice at once (a duplicate tap / network retry). Under
    // contention an attempt may fail cleanly; it must never double count.
    const attempts = await Promise.allSettled(ids.flatMap((id) => [1, 2].map(() =>
      submitEmployeeTaskForUser(db, employee, task(id)))));
    assert.ok(attempts.some((attempt) => attempt.status === "fulfilled"));
    await assertCountersMatchRecords();
    // The app retries a failed submission with the same request ID.
    const taskIds: string[] = [];
    for (const id of ids) taskIds.push((await submitEmployeeTaskForUser(db, employee, task(id))).taskId);
    assert.deepEqual(await assertCountersMatchRecords(), {total: 3, pending: 3});

    const reviews = await Promise.allSettled([
      ...[1, 2].map(() => reviewEmployeeTaskForAdmin(db, ADMIN, {taskId: taskIds[0], decision: "approve"})),
      ...[1, 2].map(() => reviewEmployeeTaskForAdmin(db, ADMIN, {taskId: taskIds[1], decision: "reject"})),
    ]);
    assert.ok(reviews.some((review) => review.status === "fulfilled"));
    await assertCountersMatchRecords();
    await reviewEmployeeTaskForAdmin(db, ADMIN, {taskId: taskIds[0], decision: "approve"});
    await reviewEmployeeTaskForAdmin(db, ADMIN, {taskId: taskIds[1], decision: "reject"});
    assert.deepEqual(await assertCountersMatchRecords(), {total: 3, pending: 1});
    assert.equal((await db.doc("users/emp-c").get()).get("cashBonusBalance"), 10, "bonus credited once");
    assert.equal((await ledger("cash_bonus_transactions", "userId", "emp-c")).length, 1);
  });
});

describe("adjustUserBalance backend", () => {
  beforeEach(async () => {
    await clear();
    await db.doc("users/cust").set({role: "customer", status: "active", bugBucks: 100, cashBonusBalance: 0});
  });

  const request = (requestId: string, overrides: Record<string, unknown> = {}) => ({
    targetUid: "cust", requestId, bugBucksDelta: 10, cashBonusDelta: 0, reason: "Goodwill credit", ...overrides,
  });

  it("applies concurrent adjustments without losing updates", async () => {
    await Promise.all(Array.from({length: 8}, (_, index) =>
      adjustUserBalanceForAdmin(db, ADMIN, request(`concurrent_request_${index}_abcdef`))));
    assert.equal((await db.doc("users/cust").get()).get("bugBucks"), 180);
    const entries = (await ledger("bugbucks_transactions", "userId", "cust"))
      .map((doc) => [doc.get("balanceBefore"), doc.get("balanceAfter")] as [number, number])
      .sort((a, b) => a[0] - b[0]);
    assert.equal(entries.length, 8);
    entries.forEach(([before, after], index) => assert.deepEqual([before, after], [100 + index * 10, 110 + index * 10]));
  });

  it("applies a retried request once and refuses reuse with different details", async () => {
    const first = await adjustUserBalanceForAdmin(db, ADMIN, request("retry_request_abcdef01"));
    const again = await adjustUserBalanceForAdmin(db, ADMIN, request("retry_request_abcdef01"));
    assert.deepEqual([first.alreadyApplied, again.alreadyApplied, again.bugBucksAfter], [false, true, 110]);
    assert.equal((await db.doc("users/cust").get()).get("bugBucks"), 110);
    assert.equal((await ledger("bugbucks_transactions", "userId", "cust")).length, 1);
    await assert.rejects(() => adjustUserBalanceForAdmin(db, ADMIN, request("retry_request_abcdef01", {bugBucksDelta: 50})),
      rejectsWith("already-exists"));
  });

  it("refuses negative balances and closed accounts without writing", async () => {
    await assert.rejects(() => adjustUserBalanceForAdmin(db, ADMIN, request("negative_request_abc01", {bugBucksDelta: -101})),
      rejectsWith("failed-precondition"));
    await assert.rejects(() => adjustUserBalanceForAdmin(db, ADMIN, request("negative_request_abc02", {bugBucksDelta: 0, cashBonusDelta: -1})),
      rejectsWith("failed-precondition"));
    assert.equal((await db.doc("users/cust").get()).get("bugBucks"), 100);
    assert.equal((await ledger("bugbucks_transactions", "userId", "cust")).length, 0);
    await db.doc("users/closed").set({status: "deleted", isDeleted: true, bugBucks: 0});
    await assert.rejects(() => adjustUserBalanceForAdmin(db, ADMIN, {...request("closed_request_abc0001"), targetUid: "closed"}),
      rejectsWith("failed-precondition"));
  });

  it("records cash adjustments in the cash ledger and never changes profile status", async () => {
    await db.doc("users/unset").set({role: "employee", bugBucks: 0});
    await adjustUserBalanceForAdmin(db, ADMIN, {
      targetUid: "unset", requestId: "cash_request_abcdef01", cashBonusDelta: 12.5, reason: "Correction",
    });
    const profile = await db.doc("users/unset").get();
    assert.deepEqual([profile.get("cashBonusBalance"), profile.get("status")], [12.5, undefined]);
    const cash = await ledger("cash_bonus_transactions", "userId", "unset");
    assert.deepEqual([cash.length, cash[0].get("balanceAfter")], [1, 12.5]);
  });

  it("validates inputs", async () => {
    for (const overrides of [{bugBucksDelta: 0, cashBonusDelta: 0}, {bugBucksDelta: 1.5}, {cashBonusDelta: 0.001},
      {reason: ""}, {requestId: "short"}]) {
      await assert.rejects(() => adjustUserBalanceForAdmin(db, ADMIN, request("valid_request_abcdef01", overrides)),
        rejectsWith("invalid-argument"));
    }
  });
});
