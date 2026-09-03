import assert from "node:assert/strict";
import {after, beforeEach, describe, it} from "node:test";
import {deleteApp, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {submitEmployeeTaskForUser} from "../src/employee-tasks.js";

const app = initializeApp({projectId: "demo-dowell"}, "task-tests");
const db = getFirestore(app);
const auth = {uid: "employee-1", token: {employee: true, email: "employee@example.com"}};
const input = {
  requestId: "task_request_123456",
  title: "Site inspection", description: "Inspect the reported infestation",
  customerName: "Customer", customerEmail: "customer@example.com",
  customerPhone: "5551234567", customerAddress: "123 Example Street",
  notes: "Evidence attached", imageUrls: ["https://storage.example/evidence.jpg"],
  imagePaths: ["task_evidence/employee-1/task_request_123456/photo_0.jpg"],
  amount: 25, type: "site_inspection", category: "service", priority: "medium",
};

async function clear() {
  for (const name of ["users", "employee_tasks"]) {
    const snapshot = await db.collection(name).get();
    await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
  }
}

describe("submitEmployeeTask backend", () => {
  beforeEach(async () => {
    await clear();
    await db.collection("users").doc(auth.uid).set({
      status: "active", displayName: "Employee", pendingTasks: 0, totalTasks: 4,
    });
  });
  after(async () => { await clear(); await deleteApp(app); });

  it("requires an authenticated employee claim and rejects trusted fields", async () => {
    await assert.rejects(() => submitEmployeeTaskForUser(db, undefined, input),
      (error: HttpsError) => error.code === "unauthenticated");
    await assert.rejects(
      () => submitEmployeeTaskForUser(db, {uid: "employee-1", token: {}}, input),
      (error: HttpsError) => error.code === "permission-denied");
    await assert.rejects(
      () => submitEmployeeTaskForUser(db, auth, {...input, status: "approved"}),
      (error: HttpsError) => error.code === "invalid-argument");
  });

  it("makes simultaneous first submissions exactly once", async () => {
    const results = await Promise.all(Array.from({length: 6},
      () => submitEmployeeTaskForUser(db, auth, input)));
    assert.equal(new Set(results.map((result) => result.taskId)).size, 1);
    assert.equal((await db.collection("employee_tasks").get()).size, 1);
    const user = await db.collection("users").doc(auth.uid).get();
    assert.equal(user.get("pendingTasks"), 1);
    assert.equal(user.get("totalTasks"), 5);
    const task = await db.collection("employee_tasks").doc(results[0].taskId).get();
    assert.equal(task.get("employeeId"), auth.uid);
    assert.equal(task.get("status"), "pending");
    assert.equal(task.get("amountAuthority"), "employee_estimate_only");
  });

  it("returns an archived task without incrementing counters again", async () => {
    const first = await submitEmployeeTaskForUser(db, auth, input);
    await db.collection("employee_tasks").doc(first.taskId).update({isDeleted: true});
    const retry = await submitEmployeeTaskForUser(db, auth, input);
    assert.equal(retry.taskId, first.taskId);
    assert.equal((await db.collection("employee_tasks").get()).size, 1);
    assert.equal((await db.collection("users").doc(auth.uid).get()).get("totalTasks"), 5);
  });

  it("rejects request ID reuse with another payload", async () => {
    await submitEmployeeTaskForUser(db, auth, input);
    await assert.rejects(
      () => submitEmployeeTaskForUser(db, auth, {...input, title: "Different task"}),
      (error: HttpsError) => error.code === "already-exists");
    assert.equal((await db.collection("employee_tasks").get()).size, 1);
  });

  it("rolls back task creation when counters are malformed", async () => {
    await db.collection("users").doc(auth.uid).update({pendingTasks: "bad"});
    await assert.rejects(() => submitEmployeeTaskForUser(db, auth, input),
      (error: HttpsError) => error.code === "failed-precondition");
    assert.equal((await db.collection("employee_tasks").get()).empty, true);
  });
});
