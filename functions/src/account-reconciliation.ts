import {FieldValue, Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {deleteAccountDataForUser} from "./account-deletion.js";

export interface ReconciliationAuth {
  getUser(uid: string): Promise<{disabled: boolean}>;
  revokeRefreshTokens(uid: string): Promise<void>;
  updateUser(uid: string, properties: {disabled: boolean}): Promise<unknown>;
}

export async function listAccountDeletionCandidates(db: Firestore) {
  const snapshots = await Promise.all(["pending", "failed"].map((status) =>
    db.collection("users").where("accountDeletionStatus", "==", status).limit(100).get()));
  const candidates = new Map<string, Record<string, unknown>>();
  for (const snapshot of snapshots) {
    for (const document of snapshot.docs) {
      candidates.set(document.id, {
        uid: document.id,
        accountDeletionStatus: document.get("accountDeletionStatus"),
        isDeleted: document.get("isDeleted") === true,
        status: document.get("status") ?? null,
      });
    }
  }
  return [...candidates.values()];
}

export async function reconcileAccountDeletionForUser(
  db: Firestore,
  auth: ReconciliationAuth,
  archiveEvidence: (paths: string[]) => Promise<void>,
  targetUid: string,
  actorUid: string,
) {
  const profile = await db.collection("users").doc(targetUid).get();
  if (!profile.exists || profile.get("isDeleted") !== true ||
      profile.get("status") !== "deleted") {
    throw new HttpsError("failed-precondition", "Target is not a soft-deleted account.");
  }
  const before = await auth.getUser(targetUid);
  await deleteAccountDataForUser(
    db, auth, archiveEvidence, targetUid, Math.floor(Date.now() / 1000));
  const after = await auth.getUser(targetUid);
  await db.collection("audit_logs").doc(`account_reconciliation_${targetUid}`).set({
    action: "ACCOUNT_DELETION_RECONCILED",
    recordCollection: "users",
    recordId: targetUid,
    subjectUid: targetUid,
    actorUid,
    actorRole: "admin",
    source: "admin",
    authDisabledBefore: before.disabled,
    authDisabledAfter: after.disabled,
    timestamp: FieldValue.serverTimestamp(),
  }, {merge: true});
  return {success: true, authDisabled: after.disabled};
}

export async function settleDeletedEmployeeTask(
  db: Firestore, taskId: string, actorUid: string,
) {
  const taskRef = db.collection("employee_tasks").doc(taskId);
  const ledgerRef = db.collection("cash_bonus_transactions").doc(`deleted_task_${taskId}`);
  return db.runTransaction(async (transaction) => {
    const [task, ledger] = await Promise.all([
      transaction.get(taskRef), transaction.get(ledgerRef),
    ]);
    if (!task.exists || task.get("isDeleted") !== true ||
        task.get("ownerAccountDeleted") !== true || task.get("status") !== "approved") {
      throw new HttpsError("failed-precondition", "Task is not an archived payable obligation.");
    }
    if (ledger.exists) return {success: true, transactionId: ledgerRef.id};
    if (task.get("isPaid") === true || task.get("paidOut") === true) {
      throw new HttpsError("failed-precondition", "Task is already settled.");
    }
    const amount = task.get("cashBonusAwarded");
    if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
      throw new HttpsError("failed-precondition", "Task settlement amount is invalid.");
    }
    const now = FieldValue.serverTimestamp();
    transaction.create(ledgerRef, {
      userId: task.get("employeeId"),
      amount,
      taskId,
      status: "settled_after_account_deletion",
      settlementAuthority: "admin_backend",
      adminId: actorUid,
      createdAt: now,
    });
    transaction.update(taskRef, {
      settlementStatus: "completed",
      settledAt: now,
      settledBy: actorUid,
      isPaid: true,
      paidOut: true,
      updatedAt: now,
    });
    return {success: true, transactionId: ledgerRef.id};
  });
}
