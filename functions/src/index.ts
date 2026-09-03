import {getAuth} from "firebase-admin/auth";
import {getStorage} from "firebase-admin/storage";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {initializeApp} from "firebase-admin/app";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {isAllowedRequestedRole, isAllowedRole} from "./role-policy.js";
import {submitReferralForUser} from "./referrals.js";
import {submitEmployeeTaskForUser} from "./employee-tasks.js";
import {deleteAccountDataForUser, revokeEvidenceTokens} from "./account-deletion.js";
import {canonicalRoleClaims, CanonicalRole} from "./role-claims.js";
import {
  listAccountDeletionCandidates,
  reconcileAccountDeletionForUser,
  settleDeletedEmployeeTask,
} from "./account-reconciliation.js";

initializeApp();

export const submitReferral = onCall(async (request) => {
  // Do not log referral input: it contains third-party PII.
  return submitReferralForUser(getFirestore(), request.auth, request.data);
});

export const submitEmployeeTask = onCall(async (request) => {
  // Do not log task input: it includes customer PII.
  return submitEmployeeTaskForUser(getFirestore(), request.auth, request.data);
});

export const deleteMyAccountData = onCall(async (request) => {
  return deleteAccountDataForUser(
    getFirestore(), getAuth(),
    (paths) => revokeEvidenceTokens(getStorage(), paths), request.auth?.uid,
    request.auth?.token.auth_time,
  );
});

export function requireAdmin(
  request: {auth?: {uid: string; token: Record<string, unknown>}},
): string {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  if (request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Administrator access is required.");
  }
  return request.auth.uid;
}

function requiredString(value: unknown, field: string, maxLength = 128): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return value.trim();
}

export const reconcileAccountDeletion = onCall(async (request) => {
  const actorUid = requireAdmin(request);
  const db = getFirestore();
  if (request.data?.targetUid == null) {
    return {candidates: await listAccountDeletionCandidates(db)};
  }
  const targetUid = requiredString(request.data.targetUid, "targetUid");
  return reconcileAccountDeletionForUser(
    db, getAuth(), (paths) => revokeEvidenceTokens(getStorage(), paths),
    targetUid, actorUid,
  );
});

export const settleDeletedEmployeeTaskPayment = onCall(async (request) => {
  const actorUid = requireAdmin(request);
  const taskId = requiredString(request.data?.taskId, "taskId");
  return settleDeletedEmployeeTask(getFirestore(), taskId, actorUid);
});

function optionalNotes(value: unknown): string | null {
  if (value == null || value === "") return null;
  if (typeof value !== "string" || value.length > 2000) {
    throw new HttpsError("invalid-argument", "notes is invalid.");
  }
  return value.trim();
}

async function applyRoleClaims(targetUid: string, role: CanonicalRole): Promise<void> {
  const auth = getAuth();
  const target = await auth.getUser(targetUid);
  const existing = target.customClaims ?? {};
  const removesPrivilege = (existing.admin === true && role !== "admin") ||
    (existing.employee === true && role !== "employee");
  await auth.setCustomUserClaims(targetUid, canonicalRoleClaims(role, existing));
  if (removesPrivilege) {
    await auth.revokeRefreshTokens(targetUid);
  }
}

export const setUserRole = onCall(async (request) => {
  const actorUid = requireAdmin(request);
  const targetUid = requiredString(request.data?.targetUid, "targetUid");
  const role = requiredString(request.data?.role, "role", 32);
  const reason = requiredString(request.data?.reason, "reason", 1000);

  if (!isAllowedRole(role)) {
    throw new HttpsError("invalid-argument", "role is not allowed.");
  }

  const db = getFirestore();
  const userRef = db.collection("users").doc(targetUid);
  const auditRef = db.collection("audit_logs").doc();
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(userRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Target user profile was not found.");
    }
    const previousRole = snapshot.get("role") ?? "customer";
    transaction.update(userRef, {
      role,
      previousRole,
      roleUpdatedAt: FieldValue.serverTimestamp(),
      roleUpdatedBy: actorUid,
      roleChangeReason: reason,
      claimSyncStatus: "pending",
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(auditRef, {
      action: "ROLE_CHANGE",
      actorUid,
      targetUid,
      previousRole,
      newRole: role,
      reason,
      timestamp: FieldValue.serverTimestamp(),
      claimSyncStatus: "pending",
    });
  });

  try {
    await applyRoleClaims(targetUid, role as CanonicalRole);
    const batch = db.batch();
    batch.update(userRef, {claimSyncStatus: "synchronized"});
    batch.update(auditRef, {claimSyncStatus: "synchronized"});
    await batch.commit();
  } catch (error) {
    console.error("Role claim synchronization failed", {targetUid, error});
    const batch = db.batch();
    batch.update(userRef, {claimSyncStatus: "failed"});
    batch.update(auditRef, {claimSyncStatus: "failed"});
    await batch.commit();
    throw new HttpsError("internal", "Role authorization could not be synchronized.");
  }

  return {success: true, tokenRefreshRequired: true};
});

export const reviewRoleRequest = onCall(async (request) => {
  const actorUid = requireAdmin(request);
  const requestId = requiredString(request.data?.requestId, "requestId");
  const decision = requiredString(request.data?.decision, "decision", 16);
  const notes = optionalNotes(request.data?.notes);
  if (decision !== "approve" && decision !== "reject") {
    throw new HttpsError("invalid-argument", "decision is invalid.");
  }

  const db = getFirestore();
  const requestRef = db.collection("role_requests").doc(requestId);
  const requestSnapshot = await requestRef.get();
  if (!requestSnapshot.exists || requestSnapshot.get("status") !== "pending" ||
      requestSnapshot.get("isDeleted") === true) {
    throw new HttpsError("failed-precondition", "Role request is not pending.");
  }

  const targetUid = requiredString(requestSnapshot.get("userId"), "userId");
  const requestedRole = requiredString(
    requestSnapshot.get("requestedRole"),
    "requestedRole",
    32,
  );
  if (!isAllowedRequestedRole(requestedRole)) {
    throw new HttpsError("failed-precondition", "Requested role is not allowed.");
  }

  const userRef = db.collection("users").doc(targetUid);
  const auditRef = db.collection("audit_logs").doc();
  await db.runTransaction(async (transaction) => {
    const [freshRequest, userSnapshot] = await Promise.all([
      transaction.get(requestRef),
      transaction.get(userRef),
    ]);
    if (!freshRequest.exists || freshRequest.get("status") !== "pending" ||
        freshRequest.get("isDeleted") === true) {
      throw new HttpsError("failed-precondition", "Role request is not pending.");
    }
    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "Target user profile was not found.");
    }
    if (userSnapshot.get("status") === "deleted" ||
        userSnapshot.get("isDeleted") === true) {
      throw new HttpsError("failed-precondition", "Target account is deleted.");
    }

    const now = FieldValue.serverTimestamp();
    const userUpdate: Record<string, unknown> = {
      needsVerification: false,
      requestedRole: FieldValue.delete(),
      status: "active",
      updatedAt: now,
    };
    if (decision === "approve") {
      userUpdate.role = requestedRole;
      userUpdate.approvedBy = actorUid;
      userUpdate.approvedAt = now;
      userUpdate.approvalNotes = notes;
      userUpdate.claimSyncStatus = "pending";
    } else {
      userUpdate.rejectedBy = actorUid;
      userUpdate.rejectedAt = now;
      userUpdate.rejectionReason = notes;
    }

    transaction.update(userRef, userUpdate);
    transaction.update(requestRef, {
      status: decision === "approve" ? "approved" : "rejected",
      reviewedAt: now,
      reviewedBy: actorUid,
      notes,
    });
    transaction.set(auditRef, {
      action: decision === "approve" ? "ROLE_REQUEST_APPROVED" : "ROLE_REQUEST_REJECTED",
      actorUid,
      targetUid,
      requestId,
      requestedRole,
      notes,
      claimSyncStatus: decision === "approve" ? "pending" : "not-required",
      timestamp: now,
    });
  });

  if (decision === "approve") {
    try {
      await applyRoleClaims(targetUid, requestedRole as CanonicalRole);
      const batch = db.batch();
      batch.update(userRef, {claimSyncStatus: "synchronized"});
      batch.update(requestRef, {claimSyncStatus: "synchronized"});
      batch.update(auditRef, {claimSyncStatus: "synchronized"});
      await batch.commit();
    } catch (error) {
      console.error("Role request claim synchronization failed", {
        requestId,
        targetUid,
        error,
      });
      const batch = db.batch();
      batch.update(userRef, {claimSyncStatus: "failed"});
      batch.update(requestRef, {claimSyncStatus: "failed"});
      batch.update(auditRef, {claimSyncStatus: "failed"});
      await batch.commit();
      throw new HttpsError("internal", "Role authorization could not be synchronized.");
    }
  }

  return {success: true, tokenRefreshRequired: decision === "approve"};
});
