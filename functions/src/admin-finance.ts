import {createHash} from "node:crypto";
import {FieldValue, Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

// Trusted admin money movements. Balances and their ledgers change only here,
// inside one Firestore transaction, so concurrent admin actions cannot lose
// updates and retries cannot credit twice. Profile status is never changed.

const MAX_AMOUNT = 1_000_000;
/** Upper bound for the configured standard task bonus (sanity check on settings). */
export const MAX_TASK_BONUS = 1000;
export const TASK_BONUS_SETTING = "app_settings/reward_settings.employee_cash_bonus";

/**
 * The standard bonus for an approved task, from app settings. Missing or
 * invalid configuration fails the approval: no zero or default is awarded.
 */
export function configuredTaskBonus(settings: FirebaseFirestore.DocumentData | undefined): number {
  const value = settings?.employee_cash_bonus;
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0 ||
      value > MAX_TASK_BONUS || cents(value) !== value) {
    console.error("Task approval blocked by invalid bonus configuration", {setting: TASK_BONUS_SETTING});
    throw new HttpsError("failed-precondition", "The employee task bonus is not configured correctly.",
      {reason: "bonus-configuration-invalid"});
  }
  return value;
}

function hash(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function cents(value: number): number {
  return Math.round(value * 100) / 100;
}

function text(value: unknown, field: string, max: number, required = true): string {
  if (value == null && !required) return "";
  if (typeof value !== "string" || value.length > max || (required && value.trim().length === 0)) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return value.trim();
}

function balance(value: unknown, field: string): number {
  if (value == null) return 0;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    console.error("Balance operation blocked by malformed numeric state", {field});
    throw new HttpsError("failed-precondition", "Account balance requires review.");
  }
  return value;
}

function isClosed(data: FirebaseFirestore.DocumentData | undefined): boolean {
  return data?.status === "deleted" || data?.isDeleted === true;
}

// ─── Task review ─────────────────────────────────────────────────────────────

export interface TaskReviewResult {
  success: true;
  taskId: string;
  status: "approved" | "rejected";
  alreadyReviewed: boolean;
  cashBonusAwarded?: number;
  balanceAfter?: number;
}

export async function reviewEmployeeTaskForAdmin(
  db: Firestore, actorUid: string, data: unknown,
): Promise<TaskReviewResult> {
  const raw = (data ?? {}) as Record<string, unknown>;
  const taskId = text(raw.taskId, "taskId", 128);
  const decision = text(raw.decision, "decision", 16);
  if (decision !== "approve" && decision !== "reject") {
    throw new HttpsError("invalid-argument", "decision is invalid.");
  }
  const notes = text(raw.notes, "notes", 2000, false);
  if (raw.bonusAmount !== undefined) {
    // The bonus comes only from app settings; a client amount is never trusted.
    throw new HttpsError("invalid-argument", "bonusAmount is not accepted; the configured bonus applies.");
  }
  const expected = raw.expectedBonusAmount;
  if (expected !== undefined && (typeof expected !== "number" || !Number.isFinite(expected))) {
    throw new HttpsError("invalid-argument", "expectedBonusAmount is invalid.");
  }
  const status = decision === "approve" ? "approved" : "rejected";
  const taskRef = db.collection("employee_tasks").doc(taskId);
  const ledgerRef = db.collection("cash_bonus_transactions").doc(`task_bonus_${taskId}`);
  const auditRef = db.collection("audit_logs").doc(`task_review_${taskId}`);
  const settingsRef = db.collection("app_settings").doc("reward_settings");

  return db.runTransaction(async (transaction) => {
    const task = await transaction.get(taskRef);
    if (!task.exists) throw new HttpsError("not-found", "Task was not found.");
    if (task.get("isDeleted") === true) throw new HttpsError("failed-precondition", "Task is archived.");

    // Already reviewed: an identical repeat is a no-op; anything else is refused.
    // An identical repeat returns the stored outcome without re-reading settings.
    if (task.get("status") !== "pending") {
      if (task.get("status") !== status) {
        throw new HttpsError("failed-precondition", "Task has already been reviewed.");
      }
      return {
        success: true, taskId, status, alreadyReviewed: true,
        ...(decision === "approve" ? {cashBonusAwarded: task.get("cashBonusAwarded")} : {}),
      };
    }

    const employeeId = task.get("employeeId");
    if (typeof employeeId !== "string" || employeeId.length === 0) {
      throw new HttpsError("failed-precondition", "Task has no owner.");
    }
    const userRef = db.collection("users").doc(employeeId);
    const [user, ledger, settings] = await Promise.all([
      transaction.get(userRef), transaction.get(ledgerRef), transaction.get(settingsRef),
    ]);
    if (!user.exists || isClosed(user.data())) {
      throw new HttpsError("failed-precondition", "Task owner account is not available.");
    }
    if (ledger.exists) throw new HttpsError("failed-precondition", "Task bonus state is inconsistent.");

    const now = FieldValue.serverTimestamp();
    const pendingTasks = Math.max(0, balance(user.get("pendingTasks"), "pendingTasks") - 1);
    const taskUpdate: Record<string, unknown> = {
      status, adminNotes: notes, reviewedBy: actorUid, reviewedAt: now, updatedAt: now,
    };
    const audit: Record<string, unknown> = {
      action: decision === "approve" ? "TASK_APPROVED" : "TASK_REJECTED",
      actorUid, targetUid: employeeId, taskId, notes, timestamp: now,
    };
    let balanceAfter: number | undefined;
    let amount = 0;
    if (decision === "approve") {
      amount = configuredTaskBonus(settings.data());
      if (expected !== undefined && expected !== amount) {
        throw new HttpsError("failed-precondition", "The configured task bonus changed; reload and retry.",
          {reason: "bonus-changed", configuredBonusAmount: amount});
      }
      const before = balance(user.get("cashBonusBalance"), "cashBonusBalance");
      balanceAfter = cents(before + amount);
      Object.assign(taskUpdate, {
        cashBonusAwarded: amount, bonusSource: TASK_BONUS_SETTING, bonusCreditedToBalance: true, paidOut: false,
        approvedBy: actorUid, approvedAt: now, cashBonusTransactionId: ledgerRef.id,
      });
      transaction.create(ledgerRef, {
        userId: employeeId, taskId, type: "task_bonus", status: "credited", amount, bonusSource: TASK_BONUS_SETTING,
        balanceBefore: before, balanceAfter, adminId: actorUid, createdAt: now,
      });
      transaction.update(userRef, {cashBonusBalance: balanceAfter, pendingTasks, updatedAt: now});
      Object.assign(audit, {amount, bonusSource: TASK_BONUS_SETTING, balanceBefore: before, balanceAfter});
    } else {
      Object.assign(taskUpdate, {rejectedBy: actorUid, rejectedAt: now});
      transaction.update(userRef, {pendingTasks, updatedAt: now});
    }
    transaction.update(taskRef, taskUpdate);
    transaction.create(auditRef, audit);
    return {
      success: true, taskId, status, alreadyReviewed: false,
      ...(decision === "approve" ? {cashBonusAwarded: amount, balanceAfter} : {}),
    };
  });
}

// ─── Balance adjustment ──────────────────────────────────────────────────────

export interface BalanceAdjustmentResult {
  success: true;
  adjustmentId: string;
  alreadyApplied: boolean;
  bugBucksAfter: number;
  cashBonusAfter: number;
}

export async function adjustUserBalanceForAdmin(
  db: Firestore, actorUid: string, data: unknown,
): Promise<BalanceAdjustmentResult> {
  const raw = (data ?? {}) as Record<string, unknown>;
  const targetUid = text(raw.targetUid, "targetUid", 128);
  const requestId = text(raw.requestId, "requestId", 128);
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
  const reason = text(raw.reason, "reason", 1000);
  const bugBucksDelta = raw.bugBucksDelta ?? 0;
  const cashBonusDelta = raw.cashBonusDelta ?? 0;
  if (typeof bugBucksDelta !== "number" || !Number.isSafeInteger(bugBucksDelta) ||
      Math.abs(bugBucksDelta) > MAX_AMOUNT) {
    throw new HttpsError("invalid-argument", "bugBucksDelta is invalid.");
  }
  if (typeof cashBonusDelta !== "number" || !Number.isFinite(cashBonusDelta) ||
      Math.abs(cashBonusDelta) > MAX_AMOUNT || cents(cashBonusDelta) !== cashBonusDelta) {
    throw new HttpsError("invalid-argument", "cashBonusDelta is invalid.");
  }
  if (bugBucksDelta === 0 && cashBonusDelta === 0) {
    throw new HttpsError("invalid-argument", "At least one adjustment is required.");
  }

  const adjustmentId = hash(`${actorUid}:${requestId}`);
  const payloadHash = hash(JSON.stringify([targetUid, bugBucksDelta, cashBonusDelta, reason]));
  const userRef = db.collection("users").doc(targetUid);
  const auditRef = db.collection("audit_logs").doc(`balance_adjustment_${adjustmentId}`);
  const bugBucksRef = db.collection("bugbucks_transactions").doc(`admin_adjustment_${adjustmentId}`);
  const cashRef = db.collection("cash_bonus_transactions").doc(`admin_adjustment_${adjustmentId}`);

  return db.runTransaction(async (transaction) => {
    const [audit, user] = await Promise.all([transaction.get(auditRef), transaction.get(userRef)]);
    if (audit.exists) {
      // Retry of an applied request: return its stored result, never reapply.
      if (audit.get("payloadHash") !== payloadHash) {
        throw new HttpsError("already-exists", "Request ID is bound to another adjustment.");
      }
      return {
        success: true, adjustmentId, alreadyApplied: true,
        bugBucksAfter: audit.get("bugBucksAfter"), cashBonusAfter: audit.get("cashBonusAfter"),
      };
    }
    if (!user.exists || isClosed(user.data())) {
      throw new HttpsError("failed-precondition", "Target account is not available.");
    }
    const bugBucksBefore = balance(user.get("bugBucks"), "bugBucks");
    const cashBonusBefore = balance(user.get("cashBonusBalance"), "cashBonusBalance");
    const bugBucksAfter = bugBucksBefore + bugBucksDelta;
    const cashBonusAfter = cents(cashBonusBefore + cashBonusDelta);
    if (bugBucksAfter < 0 || cashBonusAfter < 0) {
      throw new HttpsError("failed-precondition", "Adjustment would make a balance negative.");
    }

    const now = FieldValue.serverTimestamp();
    const common = {
      userId: targetUid, type: "admin_adjustment", reason, requestId, adminId: actorUid,
      referenceId: auditRef.id, createdAt: now,
    };
    if (bugBucksDelta !== 0) {
      transaction.create(bugBucksRef, {
        ...common, amount: Math.abs(bugBucksDelta), delta: bugBucksDelta,
        adjustmentType: bugBucksDelta > 0 ? "add" : "subtract",
        balanceBefore: bugBucksBefore, balanceAfter: bugBucksAfter,
      });
    }
    if (cashBonusDelta !== 0) {
      transaction.create(cashRef, {
        ...common, status: "admin_adjustment", amount: Math.abs(cashBonusDelta), delta: cashBonusDelta,
        adjustmentType: cashBonusDelta > 0 ? "add" : "subtract",
        balanceBefore: cashBonusBefore, balanceAfter: cashBonusAfter,
      });
    }
    transaction.update(userRef, {
      bugBucks: bugBucksAfter, cashBonusBalance: cashBonusAfter,
      lastRewardAdjustment: now, updatedAt: now,
    });
    transaction.create(auditRef, {
      action: "REWARD_ADJUSTMENT", actorUid, targetUid, requestId, payloadHash, reason,
      bugBucksDelta, cashBonusDelta, bugBucksBefore, bugBucksAfter, cashBonusBefore, cashBonusAfter,
      timestamp: now,
    });
    return {success: true, adjustmentId, alreadyApplied: false, bugBucksAfter, cashBonusAfter};
  });
}
