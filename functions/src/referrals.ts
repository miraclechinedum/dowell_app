import {createHash} from "node:crypto";
import {FieldValue, Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

const FALLBACK_REWARD = 100;
const ALLOWED_FIELDS = new Set([
  "requestId", "referralName", "referralEmail", "referralPhone",
  "address", "serviceType", "notes",
]);

export interface ReferralAuth {
  uid: string;
  token: Record<string, unknown>;
}

interface ReferralInput {
  requestId: string;
  referralName: string;
  referralEmail: string;
  referralPhone: string;
  address: string;
  serviceType: string;
  notes: string;
}

function hash(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export function referralPayloadHash(input: ReferralInput): string {
  return hash(JSON.stringify([
    input.referralName.toLowerCase(), input.referralEmail,
    input.referralPhone.replace(/\D/g, ""), input.address.toLowerCase(),
    input.serviceType.toLowerCase(), input.notes.toLowerCase(),
  ]));
}

export interface ReferralResult {
  success: true;
  referralId: string;
  bugBucksAwarded: number;
  balanceAfter: number;
}

function text(value: unknown, field: string, max: number, required = true): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  const normalized = value.trim();
  if ((required && normalized.length === 0) || normalized.length > max) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return normalized;
}

export function validateReferralInput(data: unknown): ReferralInput {
  if (data == null || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "Referral details are invalid.");
  }
  const raw = data as Record<string, unknown>;
  if (Object.keys(raw).some((key) => !ALLOWED_FIELDS.has(key))) {
    throw new HttpsError("invalid-argument", "Referral details contain unsupported fields.");
  }
  const requestId = text(raw.requestId, "requestId", 128);
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(requestId)) {
    throw new HttpsError("invalid-argument", "requestId is invalid.");
  }
  const referralEmail = text(raw.referralEmail, "referralEmail", 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(referralEmail)) {
    throw new HttpsError("invalid-argument", "referralEmail is invalid.");
  }
  const referralPhone = text(raw.referralPhone, "referralPhone", 40);
  const phoneDigits = referralPhone.replace(/\D/g, "");
  if (phoneDigits.length < 7 || phoneDigits.length > 15) {
    throw new HttpsError("invalid-argument", "referralPhone is invalid.");
  }
  return {
    requestId,
    referralName: text(raw.referralName, "referralName", 120),
    referralEmail,
    referralPhone,
    address: text(raw.address, "address", 500),
    serviceType: text(raw.serviceType, "serviceType", 80),
    notes: text(raw.notes ?? "", "notes", 2000, false),
  };
}

function safeNumber(value: unknown, field: string): number {
  if (value == null) return 0;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    console.error("Referral blocked by malformed numeric state", {field});
    throw new HttpsError("failed-precondition", "Account balance requires review.");
  }
  return value;
}

function rewardAmount(value: unknown): number {
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0
    ? value : FALLBACK_REWARD;
}

function referralId(uid: string, requestId: string): string {
  return createHash("sha256").update(`${uid}:${requestId}`).digest("hex");
}

export async function submitReferralForUser(
  db: Firestore,
  auth: ReferralAuth | undefined,
  data: unknown,
): Promise<ReferralResult> {
  if (!auth) throw new HttpsError("unauthenticated", "Authentication is required.");
  if (auth.token.admin === true || auth.token.employee === true ||
      auth.token.role === "admin" || auth.token.role === "employee") {
    throw new HttpsError("failed-precondition", "This account cannot submit customer referrals.");
  }
  const input = validateReferralInput(data);
  const payloadHash = referralPayloadHash(input);
  const id = referralId(auth.uid, input.requestId);
  const userRef = db.collection("users").doc(auth.uid);
  const referralRef = db.collection("referrals").doc(id);
  const ledgerRef = db.collection("bugbucks_transactions").doc(`referral_${id}`);
  const settingsRef = db.collection("app_settings").doc("reward_settings");
  const phone = input.referralPhone.replace(/\D/g, "");
  const identityRefs = [
    db.collection("referral_identities").doc(hash(`${auth.uid}:email:${input.referralEmail}`)),
    db.collection("referral_identities").doc(hash(`${auth.uid}:phone:${phone}`)),
  ];

  return db.runTransaction(async (transaction) => {
    const [user, existing, ledger, settings, emailIdentity, phoneIdentity] = await Promise.all([
      transaction.get(userRef), transaction.get(referralRef),
      transaction.get(ledgerRef), transaction.get(settingsRef),
      transaction.get(identityRefs[0]), transaction.get(identityRefs[1]),
    ]);
    if (existing.exists) {
      if (existing.get("customerId") !== auth.uid ||
          existing.get("requestId") !== input.requestId ||
          existing.get("payloadHash") !== payloadHash ||
          existing.get("rewardState") !== "completed" || !ledger.exists) {
        throw new HttpsError(
          "already-exists", "Request ID is bound to another submission.",
          {reason: "request-id-mismatch"},
        );
      }
      if (!user.exists || user.get("status") !== "active" ||
          user.get("isDeleted") === true || user.get("needsVerification") === true) {
        throw new HttpsError("failed-precondition", "Account is not eligible for referrals.");
      }
      return {
        success: true,
        referralId: id,
        bugBucksAwarded: safeNumber(existing.get("bugBucksAwarded"), "referralReward"),
        balanceAfter: safeNumber(ledger.get("balanceAfter"), "ledgerBalance"),
      };
    }
    if (ledger.exists) {
      throw new HttpsError("failed-precondition", "Referral reward state is inconsistent.");
    }
    if (!user.exists || user.get("status") !== "active" || user.get("needsVerification") === true) {
      throw new HttpsError("failed-precondition", "Account is not eligible for referrals.");
    }
    const reservations = [emailIdentity, phoneIdentity].filter((snapshot) => snapshot.exists);
    if (reservations.length > 0) {
      throw new HttpsError(
        "already-exists", "This person was already referred by this customer.",
        {reason: "duplicate-referral"},
      );
    }
    const amount = rewardAmount(settings.get("referral_bug_bucks"));
    const before = safeNumber(user.get("bugBucks"), "bugBucks");
    const after = before + amount;
    const totalReferrals = safeNumber(user.get("totalReferrals"), "totalReferrals") + 1;
    const now = FieldValue.serverTimestamp();
    const customerName = user.get("name") ?? user.get("displayName") ?? "Customer";
    const customerEmail = typeof auth.token.email === "string"
      ? auth.token.email : (user.get("email") ?? "");

    transaction.create(referralRef, {
      ...input,
      customerId: auth.uid,
      customerName,
      customerEmail,
      normalizedReferralEmail: input.referralEmail,
      normalizedReferralPhone: input.referralPhone.replace(/\D/g, ""),
      status: "pending",
      isDeleted: false,
      bugBucksAwarded: amount,
      rewardState: "completed",
      rewardTransactionId: ledgerRef.id,
      payloadHash,
      createdAt: now,
      submittedAt: now,
      updatedAt: now,
      rewardedAt: now,
      adminNotes: "",
    });
    transaction.create(ledgerRef, {
      userId: auth.uid,
      type: "referral",
      amount,
      description: "Referral submission reward",
      referenceId: id,
      referralId: id,
      requestId: input.requestId,
      balanceBefore: before,
      balanceAfter: after,
      createdAt: now,
    });
    for (const identityRef of identityRefs) {
      transaction.create(identityRef, {
        customerId: auth.uid,
        referralId: id,
        createdAt: now,
      });
    }
    transaction.update(userRef, {
      bugBucks: after,
      totalReferrals,
      lastReferralAt: now,
      updatedAt: now,
    });
    return {success: true, referralId: id, bugBucksAwarded: amount, balanceAfter: after};
  });
}

export const REFERRAL_REWARD_FALLBACK = FALLBACK_REWARD;
