import {createHash} from "node:crypto";
import {FieldValue, Firestore} from "firebase-admin/firestore";
import {Storage} from "firebase-admin/storage";
import {HttpsError} from "firebase-functions/v2/https";

const OPERATIONAL_COLLECTIONS: Record<string, string> = {
  referrals: "customerId",
  employee_tasks: "employeeId",
  employee_cashouts: "employeeId",
  role_requests: "userId",
  notifications: "userId",
};

function deletionId(uid: string): string {
  return createHash("sha256").update(`account-deletion:${uid}`).digest("hex");
}

function evidencePaths(data: FirebaseFirestore.DocumentData): string[] {
  const paths = Array.isArray(data.imagePaths) ? data.imagePaths : [];
  const urls = [
    ...(Array.isArray(data.imageUrls) ? data.imageUrls : []),
    ...(Array.isArray(data.images) ? data.images : []),
  ];
  const decodedUrls = urls.flatMap((value) => {
    if (typeof value !== "string") return [];
    try {
      const match = new URL(value).pathname.match(/\/o\/([^/]+)/);
      return match ? [decodeURIComponent(match[1])] : [];
    } catch {
      return [];
    }
  });
  return [...new Set([...paths, ...decodedUrls].filter((value): value is string =>
    typeof value === "string" && value.startsWith("task_evidence/")))];
}

async function softDeleteMatches(
  db: Firestore, collection: string, field: string, uid: string,
): Promise<string[]> {
  const paths: string[] = [];
  const snapshot = await db.collection(collection).where(field, "==", uid).get();
  for (let offset = 0; offset < snapshot.docs.length; offset += 400) {
    const batch = db.batch();
    snapshot.docs.slice(offset, offset + 400).forEach((document) => {
      if (collection === "employee_tasks") paths.push(...evidencePaths(document.data()));
      const update: Record<string, unknown> = {
        isDeleted: true,
        deletedAt: FieldValue.serverTimestamp(),
        deletedBy: uid,
        deletedSource: "self",
        ownerAccountDeleted: true,
      };
      if (collection === "employee_tasks") {
        update.imagePaths = evidencePaths(document.data());
        update.imageUrls = [];
        update.images = [];
        const unpaid = document.get("isPaid") !== true && document.get("paidOut") !== true;
        if (unpaid && document.get("status") === "approved") {
          update.deletedOwnerTaskState = "outstanding_payment";
          update.settlementStatus = "pending";
        } else if (unpaid && document.get("status") === "pending") {
          update.deletedOwnerTaskState = "pending_review";
        }
      }
      batch.update(document.ref, update);
    });
    await batch.commit();
  }
  return paths;
}

export async function revokeEvidenceTokens(storage: Storage, paths: string[]): Promise<void> {
  const bucket = storage.bucket();
  for (const path of paths) {
    const file = bucket.file(path);
    const [exists] = await file.exists();
    if (!exists) continue;
    await file.setMetadata({
      metadata: {firebaseStorageDownloadTokens: null, archived: "true"},
    });
  }
}

async function recordFailure(db: Firestore, uid: string, auditId: string): Promise<void> {
  const batch = db.batch();
  batch.set(db.collection("users").doc(uid), {
    accountDeletionStatus: "failed",
    accountDeletionLastAttemptAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  batch.set(db.collection("audit_logs").doc(auditId), {
    outcome: "failed",
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await batch.commit();
}

export async function deleteAccountDataForUser(
  db: Firestore,
  auth: {
    revokeRefreshTokens(uid: string): Promise<void>;
    updateUser(uid: string, properties: {disabled: boolean}): Promise<unknown>;
  },
  archiveEvidence: (paths: string[]) => Promise<void>,
  uid: string | undefined,
  authTime: unknown,
): Promise<{success: true}> {
  if (!uid) throw new HttpsError("unauthenticated", "Authentication is required.");
  if (typeof authTime !== "number" || Date.now() / 1000 - authTime > 300) {
    throw new HttpsError("failed-precondition", "Recent authentication is required.");
  }

  const userRef = db.collection("users").doc(uid);
  const auditId = deletionId(uid);
  const auditRef = db.collection("audit_logs").doc(auditId);
  const profile = await userRef.get();
  if (!profile.exists) throw new HttpsError("not-found", "Account profile was not found.");

  const start = db.batch();
  start.update(userRef, {
    isDeleted: true,
    status: "deleted",
    deletedAt: FieldValue.serverTimestamp(),
    deletedBy: uid,
    deletedSource: "self",
    accountDeletionStatus: "pending",
    accountDeletionLastAttemptAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  start.set(auditRef, {
    action: "ACCOUNT_SOFT_DELETED",
    recordCollection: "users",
    recordId: uid,
    subjectUid: uid,
    actorUid: uid,
    actorRole: "self",
    source: "self",
    timestamp: FieldValue.serverTimestamp(),
    outcome: "pending",
  }, {merge: true});
  await start.commit();

  try {
    const allEvidencePaths: string[] = [];
    for (const [collection, field] of Object.entries(OPERATIONAL_COLLECTIONS)) {
      allEvidencePaths.push(...await softDeleteMatches(db, collection, field, uid));
    }
    await archiveEvidence(allEvidencePaths);
    await auth.revokeRefreshTokens(uid);
    await auth.updateUser(uid, {disabled: true});

    const complete = db.batch();
    complete.update(userRef, {
      accountDeletionStatus: "completed",
      accountDeletionCompletedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    complete.set(auditRef, {
      outcome: "completed",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await complete.commit();
    return {success: true};
  } catch (error) {
    console.error("Account deactivation synchronization failed", {uid, error});
    await recordFailure(db, uid, auditId);
    throw new HttpsError(
      "internal", "Account deactivation could not be completed. It is safe to retry.",
    );
  }
}
