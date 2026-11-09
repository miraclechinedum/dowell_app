import {profileDefaults} from "../profile-defaults.js";
import {
  Encoded, EncodedTimestamp, SCHEMA_TAG, isEncodedTimestamp, sha256, stableStringify,
  timestampFromIso,
} from "./common.js";

// Pure planning for the legacy (dowell-pest-control) → current schema migration.
// Input: a read-only source snapshot, approved business decisions, and the
// Storage copy map. Output: deterministic target writes plus issues. Nothing
// here talks to Firebase, so the plan can be reviewed and unit-tested offline.
//
// Invariants:
// - Document IDs and paths are preserved; original fields are never removed.
// - Every non-zero legacy balance is mapped exactly once or explicitly marked
//   superseded; otherwise the plan has a blocker.
// - Legacy ledgers are archived unchanged; the new ledgers start from one
//   deterministic opening-balance entry per user, so history is never replayed.

export type Doc = {[key: string]: Encoded};
export type Severity = "blocker" | "warning" | "info";

export interface Issue {
  severity: Severity;
  code: string;
  path?: string;
  detail?: string;
}

export interface SnapshotDoc {
  path: string;
  data: Doc;
}

export interface StorageObject {
  name: string;
  size: number;
  md5: string | null;
  contentType: string | null;
}

export interface Snapshot {
  formatVersion: 1;
  sourceProject: string;
  takenAt: string;
  snapshotId: string;
  documents: SnapshotDoc[];
  /** `exists: false` when the source bucket was never provisioned. */
  storage: {bucket: string; exists?: boolean; objects: StorageObject[]};
}

export const BALANCE_FIELDS = ["walletBalance", "bugBucks", "cashBalance", "cashBonusBalance"] as const;
export type BalanceField = typeof BALANCE_FIELDS[number];
export type BalanceSource = BalanceField | "zero";

export interface RoleBalanceMapping {
  bugBucks: BalanceSource;
  cashBonusBalance: BalanceSource;
  /** Non-zero legacy fields acknowledged as stale; kept under legacyBalances only. */
  superseded?: BalanceField[];
}

export interface Decisions {
  approved: boolean;
  /** ISO time used for opening-balance entries and the migration audit log. */
  cutoverAt: string;
  /** Keyed by legacy users.role; "(missing)" covers profiles without a role. */
  balanceMapping: Record<string, RoleBalanceMapping>;
  ledgerMismatchPolicy: "block" | "trust-balance-field";
  pendingPayoutPolicy: "block" | "carry-as-obligation";
  /** Optional legacy status → current status mapping; unmapped values are kept. */
  statusMap?: Record<string, string>;
  copyResumes: boolean;
  approvedAdminUids: string[];
  /** Accounts closed at the client's request (see ClosedAccount). */
  closedAccounts?: ClosedAccount[];
  /** Unused sign-ins excluded from the target: no Auth import, no profile. */
  excludedAccounts?: ExcludedAccount[];
  /** Legacy referral rewards the client authorised to credit at migration. */
  referralRewardCredits?: ReferralRewardCredit[];
  /**
   * Whether missing status/needsVerification fields are filled using the
   * backfill rules. Default "disabled": profiles keep their original status
   * fields and nobody is activated without an owner decision.
   */
  profileStatusBackfill?: "disabled" | "backfill-rules";
  /** Separate client-owned admin, provisioned in the target after import. */
  clientAdmin?: {email: string; approved: boolean};
}

/**
 * An account closed at the client's request. Personal data owned by the
 * account is redacted or not migrated; financial records are retained with the
 * account pseudonymised by UID. Money is never moved: each disposition only
 * records what the client decided, and "unresolved" is always a blocker.
 */
export interface ClosedAccount {
  uid: string;
  /** Where the client's decision is recorded, e.g. "Dowell email 2026-10-20". */
  decisionReference: string;
  /** "none" is only valid when the account has no balance / no pending payout. */
  legacyBalanceDisposition: "none" | "unresolved" | "settled" | "written-off" | "retain-as-obligation";
  pendingPayoutDisposition: "none" | "unresolved" | "paid-externally" | "cancelled" | "retain-as-obligation";
  /** Required for "settled" balances and "paid-externally" payouts. */
  settlementReference?: string;
  /** Date of the client's decision, recorded in the audit trail. */
  decisionDate?: string;
  /** Recorded as the placeholder profile's deletionReason. */
  closureReason?: string;
}

/**
 * A legacy pending referral reward the client authorised to credit once at
 * migration. Credited through one deterministic ledger entry
 * (bugbucks_transactions/migration_referral_reward_{referralId}).
 */
export interface ReferralRewardCredit {
  referralId: string;
  amount: number;
  decisionReference: string;
}

export interface ExcludedAccount {
  uid: string;
  decisionReference: string;
}

/** Fields holding the owner's UID; replaced by a pseudonym for closed accounts. */
const OWNER_ID_FIELDS: Record<string, string[]> = {
  referrals: ["customerId", "referrerId"],
  employee_tasks: ["employeeId", "userId"],
  role_requests: ["userId"],
  payout_requests: ["userId"],
  transactions: ["userId"],
};

/** One-way pseudonym that replaces a closed account's UID in retained records. */
export function closedAccountPseudonym(uid: string): string {
  return `closed-account-${sha256(`dowell-closed-account:${uid}`).slice(0, 16)}`;
}

const OWNER_PII: Record<string, string[]> = {
  referrals: ["customerName", "customerEmail"],
  employee_tasks: ["employeeName", "employeeEmail", "photos", "legacyPhotoUrls", "images", "imageUrls", "imagePaths"],
  role_requests: ["userEmail", "userName", "reason", "supportingInfo", "resumeDownloadUrl", "resumeFileName", "resumeAttached"],
  payout_requests: ["accountDetails"],
};

export interface StorageMapEntry {
  sourcePath: string;
  path: string;
  url: string | null;
}

export interface StorageMap {
  bucket: string;
  taskPhotos: Record<string, StorageMapEntry[]>;
}

export interface PlannedWrite {
  path: string;
  origin: "copy" | "transform" | "derived";
  data: Doc;
  contentHash: string;
}

export interface Plan {
  snapshotId: string;
  writes: PlannedWrite[];
  issues: Issue[];
  summary: Record<string, Encoded>;
}

const TRANSFORMED = new Set(["users", "referrals", "employee_tasks", "role_requests", "app_settings"]);
const COPIED = new Set([
  "transactions", "payout_requests", "notifications", "app_config", "redemptions",
  "referral_clicks", "activity_log", "bugbucks_transactions", "cash_bonus_transactions",
  "employee_cashouts", "audit_logs", "referral_identities",
]);
const TOLERANCE = 0.005;
const UNOWNED = "\u0000unowned";
/**
 * The legacy app kept Bug Bucks and cash bonuses in one wallet without a unit,
 * and the owner has not documented it. Closed-account amounts are recorded with
 * this marker rather than being labelled as Bug Bucks or currency.
 */
const LEGACY_UNIT = "undocumented-legacy-wallet-unit";

function num(value: Encoded | undefined): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function str(value: Encoded | undefined): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function fill(out: Doc, key: string, value: Encoded | undefined): void {
  if (out[key] === undefined && value !== undefined && value !== null) out[key] = value;
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

function tsMillis(value: Encoded | undefined): number {
  return isEncodedTimestamp(value) ? value.seconds * 1000 + value.nanoseconds / 1e6 : 0;
}

function idOf(path: string): string {
  return path.slice(path.lastIndexOf("/") + 1);
}

function rootOf(path: string): string {
  return path.split("/")[0];
}

export function contentHashOf(data: Doc): string {
  const rest: Doc = {...data};
  delete rest.migration;
  return sha256(stableStringify(rest));
}

function finalize(path: string, origin: PlannedWrite["origin"], data: Doc): PlannedWrite {
  const contentHash = contentHashOf(data);
  return {
    path, origin, contentHash,
    data: {
      ...data,
      migration: {
        schema: SCHEMA_TAG,
        sourceProject: "dowell-pest-control",
        sourcePath: origin === "derived" ? null : path,
        contentHash,
      },
    },
  };
}

/** Signed effect of one legacy `transactions` entry on users.walletBalance. */
export function legacyDelta(tx: Doc): number | undefined {
  const amount = num(tx.amount);
  if (amount === undefined) return undefined;
  switch (tx.type) {
  case "referral_bonus":
  case "task_bonus":
  case "admin_adjustment":
    return amount;
  case "payout":
  case "redemption":
    return -Math.abs(amount);
  default:
    return undefined;
  }
}

/** Parses a Firebase Storage download URL into its object path. */
export function storagePathFromUrl(url: string): string | undefined {
  try {
    const match = new URL(url).pathname.match(/\/o\/([^/]+)$/);
    return match ? decodeURIComponent(match[1]) : undefined;
  } catch {
    return undefined;
  }
}

export function legacyTaskPhotoTarget(employeeId: string, taskId: string, sourcePath: string): string {
  return `task_evidence/${employeeId}/legacy_${taskId}/${sourcePath.slice(sourcePath.lastIndexOf("/") + 1)}`;
}

export function buildPlan(snapshot: Snapshot, decisions: Decisions, storageMap?: StorageMap): Plan {
  const issues: Issue[] = [];
  const writes: PlannedWrite[] = [];
  const issue = (severity: Severity, code: string, path?: string, detail?: string) =>
    issues.push({severity, code, path, detail});
  const cutover: EncodedTimestamp = timestampFromIso(decisions.cutoverAt);

  const byRoot = new Map<string, SnapshotDoc[]>();
  for (const doc of snapshot.documents) {
    const root = rootOf(doc.path);
    byRoot.set(root, [...(byRoot.get(root) ?? []), doc]);
  }
  const rootDocs = (name: string) =>
    (byRoot.get(name) ?? []).filter((doc) => doc.path.split("/").length === 2);
  const users = new Map(rootDocs("users").map((doc) => [idOf(doc.path), doc.data]));
  const closed = new Map((decisions.closedAccounts ?? []).map((account) => [account.uid, account]));
  const excluded = new Map((decisions.excludedAccounts ?? []).map((account) => [account.uid, account]));
  const pseudonymise = (out: Doc, collection: string, uid: string): void => {
    for (const field of OWNER_ID_FIELDS[collection] ?? []) {
      if (out[field] === uid) out[field] = closedAccountPseudonym(uid);
    }
    out.ownerPseudonymised = true;
  };
  const closedStats = {redactedRecords: 0, purgedRecords: 0, thirdPartyRecordsRetained: 0};
  /** Redacts the closed owner's own personal data and soft-deletes the record. */
  const closeRecord = (out: Doc, collection: string, uid: string): void => {
    const removed = (OWNER_PII[collection] ?? []).filter((field) => out[field] !== undefined);
    for (const field of removed) delete out[field];
    pseudonymise(out, collection, uid);
    out.isDeleted = true;
    out.ownerAccountDeleted = true;
    out.deletedSource = "admin";
    out.deletionReason = "owner-account-closed-at-client-request";
    out.deletedAt = cutover;
    if (removed.length > 0) out.redactedFields = removed;
    closedStats.redactedRecords++;
  };

  // ─── Indexes used by several transforms ─────────────────────────────────
  const txByUser = new Map<string, SnapshotDoc[]>();
  for (const tx of rootDocs("transactions")) {
    // Entries without a userId are grouped under one ownerless key so they are
    // counted as stranded below instead of being skipped.
    const uid = str(tx.data.userId) ?? UNOWNED;
    txByUser.set(uid, [...(txByUser.get(uid) ?? []), tx]);
  }
  const referralTx = new Map<string, string>();
  for (const tx of rootDocs("transactions")) {
    const ref = str(tx.data.referenceId);
    if (tx.data.type === "referral_bonus" && ref) referralTx.set(ref, idOf(tx.path));
  }
  const newLedgerOwners = new Set(
    [...rootDocs("bugbucks_transactions"), ...rootDocs("cash_bonus_transactions")]
      .map((doc) => str(doc.data.userId)).filter((uid): uid is string => uid !== undefined),
  );
  const referralOwner = (data: Doc) => str(data.customerId) ?? str(data.referrerId);
  const taskOwner = (data: Doc) => str(data.employeeId) ?? str(data.userId);

  // ─── Classification of every source collection ─────────────────────────
  for (const root of byRoot.keys()) {
    if (!TRANSFORMED.has(root) && !COPIED.has(root)) {
      issue("blocker", "unclassified-collection", root, "Decide whether to copy, transform, or archive it.");
    }
  }

  // ─── Money and obligation totals ───────────────────────────────────────
  const totals = {
    legacy: Object.fromEntries(BALANCE_FIELDS.map((field) => [field, 0])) as Record<BalanceField, number>,
    openingBugBucks: 0,
    openingCashBonus: 0,
    pendingPayouts: {count: 0, amount: 0},
    pendingReferralRewards: {count: 0, amount: 0},
    approvedTaskBonuses: {count: 0, amount: 0},
    ledgerMismatches: 0,
  };
  const pendingPayoutByUser = new Map<string, number>();
  for (const payout of rootDocs("payout_requests")) {
    if (payout.data.status !== "pending") continue;
    const amount = num(payout.data.amount) ?? 0;
    const uid = str(payout.data.userId) ?? "(missing)";
    if (closed.has(uid)) continue; // Decided per closed account below.
    totals.pendingPayouts.count++;
    totals.pendingPayouts.amount += amount;
    pendingPayoutByUser.set(uid, (pendingPayoutByUser.get(uid) ?? 0) + amount);
  }
  if (totals.pendingPayouts.count > 0) {
    issue(decisions.pendingPayoutPolicy === "block" ? "blocker" : "warning", "pending-payouts-present",
      undefined, `${totals.pendingPayouts.count} pending payout request(s).`);
  }

  // ─── Financial records whose owner has no users profile ────────────────
  // Opening balances are built per profile, so money owned by a missing profile
  // would otherwise drop out of reconciliation. These are always blockers,
  // independent of policy. Issue paths name the financial record, never the UID.
  const stranded = {
    legacyLedger: {owners: 0, entries: 0, balance: 0},
    currentLedger: {owners: 0, entries: 0, amount: 0},
    pendingPayouts: {count: 0, amount: 0},
  };
  for (const [uid, txs] of txByUser) {
    if (users.has(uid) || closed.has(uid)) continue;
    const balance = txs.reduce((sum, tx) => sum + (legacyDelta(tx.data) ?? 0), 0);
    stranded.legacyLedger.owners++;
    stranded.legacyLedger.entries += txs.length;
    stranded.legacyLedger.balance += balance;
    issue("blocker", "ledger-owner-profile-missing", txs[0].path,
      `kind=legacy-ledger owner=${uid === UNOWNED ? "no-userId" : "profile-missing"} ` +
      `entries=${txs.length} balance=${round2(balance)}`);
  }
  const currentLedgerByOwner = new Map<string, SnapshotDoc[]>();
  for (const doc of [...rootDocs("bugbucks_transactions"), ...rootDocs("cash_bonus_transactions")]) {
    const uid = str(doc.data.userId);
    if (uid && (users.has(uid) || closed.has(uid))) continue;
    const key = uid ?? `(missing):${doc.path}`;
    currentLedgerByOwner.set(key, [...(currentLedgerByOwner.get(key) ?? []), doc]);
  }
  for (const docs of currentLedgerByOwner.values()) {
    const amount = docs.reduce((sum, doc) => sum + (num(doc.data.amount) ?? 0), 0);
    stranded.currentLedger.owners++;
    stranded.currentLedger.entries += docs.length;
    stranded.currentLedger.amount += amount;
    issue("blocker", "ledger-owner-profile-missing", docs[0].path,
      `kind=current-ledger entries=${docs.length} amount=${round2(amount)}`);
  }
  for (const payout of rootDocs("payout_requests")) {
    const uid = str(payout.data.userId);
    if (payout.data.status !== "pending" || (uid && (users.has(uid) || closed.has(uid)))) continue;
    const amount = num(payout.data.amount) ?? 0;
    stranded.pendingPayouts.count++;
    stranded.pendingPayouts.amount += amount;
    issue("blocker", "ledger-owner-profile-missing", payout.path,
      `kind=pending-payout amount=${round2(amount)}`);
  }

  // ─── authorised legacy referral reward credits ──────────────────────────
  // Each credit must match a converted referral whose reward is still pending
  // and was never paid by the legacy ledger. Anything else is a blocker.
  const creditByReferral = new Map<string, {owner: string; amount: number; decisionReference: string}>();
  const creditByUser = new Map<string, {referralId: string; amount: number; decisionReference: string}[]>();
  const rewardTotals = {count: 0, amount: 0};
  for (const credit of decisions.referralRewardCredits ?? []) {
    const doc = rootDocs("referrals").find((item) => idOf(item.path) === credit.referralId);
    const owner = doc ? referralOwner(doc.data) : undefined;
    const reasons: string[] = [];
    if (!doc) reasons.push("referral-not-found");
    if (creditByReferral.has(credit.referralId)) reasons.push("duplicate-credit-decision");
    if (!str(credit.decisionReference)) reasons.push("decision-reference-missing");
    if (!Number.isSafeInteger(credit.amount) || credit.amount <= 0) reasons.push("amount-invalid");
    if (doc) {
      if (doc.data.status !== "converted") reasons.push("referral-not-converted");
      if ((num(doc.data.bugBucksPending) ?? 0) !== credit.amount) reasons.push("amount-differs-from-pending-reward");
      if ((num(doc.data.bugBucksEarned) ?? 0) !== 0 || (num(doc.data.bugBucksAwarded) ?? 0) !== 0) reasons.push("reward-already-earned");
      if (doc.data.rewardedOnSubmission === true) reasons.push("rewarded-on-submission");
      if (referralTx.has(credit.referralId)) reasons.push("legacy-ledger-already-paid");
      if (!owner || !users.has(owner) || closed.has(owner) || excluded.has(owner)) reasons.push("recipient-not-active-profile");
    }
    if (reasons.length > 0) {
      issue("blocker", "referral-reward-credit-invalid", doc?.path ?? "referrals", reasons.join(","));
      continue;
    }
    creditByReferral.set(credit.referralId, {owner: owner as string, amount: credit.amount, decisionReference: credit.decisionReference});
    creditByUser.set(owner as string, [...(creditByUser.get(owner as string) ?? []),
      {referralId: credit.referralId, amount: credit.amount, decisionReference: credit.decisionReference}]);
  }
  const profileStats = {activated: 0, verificationSet: 0, staleRoleRequestsResolved: 0, review: 0, leftUnset: 0};

  // ─── users ─────────────────────────────────────────────────────────────
  const roleCounts: Record<string, number> = {};
  const statusCounts: Record<string, number> = {};
  for (const doc of rootDocs("users")) {
    const uid = idOf(doc.path);
    if (closed.has(uid)) continue; // Replaced by a closed-account profile below.
    const data = doc.data;
    const out: Doc = {...data};
    const roleKey = str(data.role) ?? "(missing)";
    roleCounts[roleKey] = (roleCounts[roleKey] ?? 0) + 1;
    const status = str(data.status) ?? "(missing)";
    statusCounts[status] = (statusCounts[status] ?? 0) + 1;

    fill(out, "displayName", data.fullName);
    fill(out, "name", data.fullName);
    fill(out, "phone", data.phoneNumber);
    const mappedStatus = str(data.status) && decisions.statusMap?.[data.status as string];
    if (mappedStatus) {
      out.legacyStatus = data.status;
      out.status = mappedStatus;
    }

    // Missing status/needsVerification: same rules as backfill-user-profiles,
    // plus resolving a stale requestedRole already granted by an approved request.
    const requests = rootDocs("role_requests").filter((request) => str(request.data.userId) === uid);
    const backfillEnabled = decisions.profileStatusBackfill === "backfill-rules";
    const needsDefaults = out.status === undefined || out.needsVerification === undefined;
    if (!backfillEnabled && needsDefaults) {
      profileStats.leftUnset++;
      issue("info", "profile-status-left-unset", doc.path, "No owner-approved activation; status fields unchanged.");
    }
    const defaults = !backfillEnabled ? null : profileDefaults(out as Record<string, unknown>, {
      approvedRequestForRole: requests.some((request) =>
        request.data.status === "approved" && request.data.requestedRole === data.role),
      pendingRequest: requests.some((request) => request.data.status === "pending"),
    });
    if (defaults === null) {
      // Owner decision: no automatic activation.
    } else if (defaults.kind === "review") {
      profileStats.review++;
      issue("warning", "profile-status-review", doc.path, defaults.reason);
    } else {
      if (defaults.update.status !== undefined) profileStats.activated++;
      if (defaults.update.needsVerification !== undefined) profileStats.verificationSet++;
      Object.assign(out, defaults.update);
      if (defaults.resolvedRequestedRole !== undefined) {
        profileStats.staleRoleRequestsResolved++;
        out.legacyRequestedRole = data.requestedRole;
        delete out.requestedRole;
      }
    }

    // Balances.
    const legacy: Partial<Record<BalanceField, number>> = {};
    for (const field of BALANCE_FIELDS) {
      if (data[field] === undefined) continue;
      const value = num(data[field]);
      if (value === undefined) {
        issue("blocker", "balance-not-numeric", doc.path, field);
        continue;
      }
      legacy[field] = value;
      totals.legacy[field] += value;
    }
    const nonZero = (Object.entries(legacy) as [BalanceField, number][])
      .filter(([, value]) => Math.abs(value) > TOLERANCE);
    const mapping = decisions.balanceMapping[roleKey];
    let bugBucks = 0;
    let cashBonus = 0;
    if (Object.keys(legacy).length > 0) out.legacyBalances = legacy;
    if (!mapping) {
      if (nonZero.length > 0) issue("blocker", "balance-mapping-missing", doc.path, `role=${roleKey}`);
    } else {
      const pick = (source: BalanceSource) => (source === "zero" ? 0 : legacy[source] ?? 0);
      bugBucks = pick(mapping.bugBucks);
      cashBonus = pick(mapping.cashBonusBalance);
      if (mapping.bugBucks !== "zero" && mapping.bugBucks === mapping.cashBonusBalance) {
        issue("blocker", "balance-double-mapped", doc.path, mapping.bugBucks);
      }
      const used = new Set<string>([mapping.bugBucks, mapping.cashBonusBalance, ...(mapping.superseded ?? [])]);
      for (const [field] of nonZero) {
        if (!used.has(field)) issue("blocker", "balance-field-unmapped", doc.path, field);
      }
      if (bugBucks < 0 || cashBonus < 0) issue("blocker", "negative-balance", doc.path);
      if (!Number.isInteger(bugBucks)) issue("warning", "fractional-bug-bucks", doc.path);
      out.bugBucks = bugBucks;
      out.cashBonusBalance = round2(cashBonus);
      if (newLedgerOwners.has(uid) && (bugBucks !== 0 || cashBonus !== 0)) {
        issue("blocker", "mixed-ledger-history", doc.path, "User already has current-schema ledger entries.");
      }
    }

    // Legacy ledger reconciliation against walletBalance.
    const txs = (txByUser.get(uid) ?? []).slice().sort((a, b) => tsMillis(a.data.createdAt) - tsMillis(b.data.createdAt));
    if (txs.length > 0) {
      let sum = 0;
      let unknown = false;
      for (const tx of txs) {
        const delta = legacyDelta(tx.data);
        if (delta === undefined) {
          unknown = true;
          issue("blocker", "unknown-transaction-type", tx.path, String(tx.data.type ?? "(missing)"));
        } else {
          sum += delta;
        }
      }
      const wallet = legacy.walletBalance;
      const lastBalance = num(txs[txs.length - 1].data.balance);
      const mismatch = !unknown && (wallet === undefined || Math.abs(sum - wallet) > TOLERANCE ||
        (lastBalance !== undefined && Math.abs(lastBalance - wallet) > TOLERANCE));
      if (mismatch) {
        totals.ledgerMismatches++;
        issue(decisions.ledgerMismatchPolicy === "block" ? "blocker" : "warning", "legacy-ledger-mismatch",
          doc.path, `ledgerSum=${round2(sum)} walletBalance=${wallet ?? "(missing)"} lastBalance=${lastBalance ?? "(missing)"}`);
      }
    }
    const pending = pendingPayoutByUser.get(uid) ?? 0;
    if (pending > (legacy.walletBalance ?? 0) + TOLERANCE) {
      issue("warning", "pending-payout-exceeds-balance", doc.path);
    }

    // Counters are recomputed from the migrated records; originals are kept.
    const counters: Doc = {};
    for (const field of ["totalReferrals", "convertedReferrals", "totalTasks", "pendingTasks"]) {
      if (data[field] !== undefined) counters[field] = data[field];
    }
    if (Object.keys(counters).length > 0) out.legacyCounters = counters;
    const ownReferrals = rootDocs("referrals").filter((ref) => referralOwner(ref.data) === uid && ref.data.isDeleted !== true);
    const ownTasks = rootDocs("employee_tasks").filter((task) => taskOwner(task.data) === uid && task.data.isDeleted !== true);
    out.totalReferrals = ownReferrals.length;
    out.convertedReferrals = ownReferrals.filter((ref) => ref.data.status === "converted").length;
    out.totalTasks = ownTasks.length;
    out.pendingTasks = ownTasks.filter((task) => task.data.status === "pending").length;

    // Authorised reward credits follow the opening balance in the new ledger.
    let runningBugBucks = bugBucks;
    for (const [index, credit] of (creditByUser.get(uid) ?? []).entries()) {
      writes.push(finalize(`bugbucks_transactions/migration_referral_reward_${credit.referralId}`, "derived", {
        userId: uid, type: "migration_referral_reward", amount: credit.amount,
        balanceBefore: runningBugBucks, balanceAfter: runningBugBucks + credit.amount,
        description: "Legacy converted-referral reward credited at migration (client-authorised)",
        referenceId: credit.referralId, referralId: credit.referralId,
        decisionReference: credit.decisionReference,
        createdAt: {__type: "timestamp", seconds: cutover.seconds + 1 + index, nanoseconds: 0},
      }));
      runningBugBucks += credit.amount;
      rewardTotals.count++;
      rewardTotals.amount += credit.amount;
    }
    if (runningBugBucks !== bugBucks) out.bugBucks = runningBugBucks;

    writes.push(finalize(doc.path, "transform", out));

    totals.openingBugBucks += bugBucks;
    totals.openingCashBonus += cashBonus;
    if (mapping && bugBucks !== 0) {
      writes.push(finalize(`bugbucks_transactions/migration_opening_${uid}`, "derived", {
        userId: uid, type: "migration_opening_balance", amount: bugBucks,
        balanceBefore: 0, balanceAfter: bugBucks,
        description: "Opening balance migrated from dowell-pest-control",
        referenceId: `users/${uid}`, sourceBalanceField: mapping.bugBucks, createdAt: cutover,
      }));
    }
    if (mapping && cashBonus !== 0) {
      writes.push(finalize(`cash_bonus_transactions/migration_opening_${uid}`, "derived", {
        userId: uid, amount: round2(cashBonus), status: "migration_opening_balance",
        description: "Opening cash bonus balance migrated from dowell-pest-control",
        referenceId: `users/${uid}`, sourceBalanceField: mapping.cashBonusBalance,
        settlementAuthority: "migration", createdAt: cutover,
      }));
    }
  }

  // ─── referrals ─────────────────────────────────────────────────────────
  for (const doc of rootDocs("referrals")) {
    const data = doc.data;
    const out: Doc = {...data};
    const owner = referralOwner(data);
    if (!owner) {
      issue("blocker", "referral-without-owner", doc.path);
    } else if (!users.has(owner) && !closed.has(owner)) {
      issue("warning", "referral-owner-profile-missing", doc.path);
    }
    fill(out, "customerId", owner);
    fill(out, "referralEmail", data.email);
    fill(out, "referralPhone", data.phoneNumber);
    fill(out, "bugBucksAwarded", data.bugBucksEarned);
    fill(out, "createdAt", data.submittedAt);
    const email = str(out.referralEmail);
    const phone = str(out.referralPhone);
    if (email) fill(out, "normalizedReferralEmail", email.trim().toLowerCase());
    if (phone) fill(out, "normalizedReferralPhone", phone.replace(/\D/g, ""));
    const profile = owner ? users.get(owner) : undefined;
    if (profile) {
      fill(out, "customerName", profile.fullName ?? profile.displayName ?? profile.name);
      fill(out, "customerEmail", profile.email);
    }
    if (out.rewardState === undefined) {
      out.rewardState = "legacy";
      const txId = referralTx.get(idOf(doc.path));
      if (txId) out.legacyRewardTransactionId = txId;
      else if (num(data.bugBucksEarned) && (num(data.bugBucksEarned) as number) > 0) {
        issue("warning", "referral-reward-without-ledger", doc.path);
      }
    }
    if (out.createdAt === undefined) issue("warning", "referral-missing-createdAt", doc.path);
    const credited = creditByReferral.get(idOf(doc.path));
    if (credited) {
      // Original bugBucksPending/bugBucksEarned stay as history.
      out.bugBucksAwarded = credited.amount;
      out.rewardState = "credited-at-migration";
      out.rewardTransactionId = `migration_referral_reward_${idOf(doc.path)}`;
      out.rewardDecisionReference = credited.decisionReference;
      out.rewardedAt = cutover;
    }
    const pendingReward = credited ? 0 : num(data.bugBucksPending) ?? 0;
    if (pendingReward > 0) {
      totals.pendingReferralRewards.count++;
      totals.pendingReferralRewards.amount += pendingReward;
    }
    if (owner && closed.has(owner)) {
      // Referred people's contact details are the client's lead records, not
      // the closed owner's personal data; only the owner's own fields go.
      closeRecord(out, "referrals", owner);
      closedStats.thirdPartyRecordsRetained++;
    }
    writes.push(finalize(doc.path, "transform", out));
  }

  // ─── employee_tasks ────────────────────────────────────────────────────
  for (const doc of rootDocs("employee_tasks")) {
    const data = doc.data;
    const taskId = idOf(doc.path);
    const out: Doc = {...data};
    const owner = taskOwner(data);
    if (!owner) issue("blocker", "task-without-owner", doc.path);
    else if (!users.has(owner) && !closed.has(owner)) issue("warning", "task-owner-profile-missing", doc.path);
    const ownerClosed = owner !== undefined && closed.has(owner);
    fill(out, "employeeId", owner);
    fill(out, "createdAt", data.submittedAt);
    fill(out, "type", data.taskType);
    fill(out, "title", data.taskType);
    fill(out, "cashBonusAwarded", data.bonusAmount);
    if (out.createdAt === undefined) issue("warning", "task-missing-createdAt", doc.path);

    const photos = Array.isArray(data.photos) ? data.photos.filter((url): url is string => typeof url === "string") : [];
    if (photos.length > 0 && !ownerClosed) {
      out.legacyPhotoUrls = photos;
      const mapped = storageMap?.taskPhotos[taskId];
      if (snapshot.storage.exists === false) {
        // The source bucket was never provisioned, so these files never existed.
        issue("warning", "task-photos-unrecoverable", doc.path, "Source bucket does not exist.");
      } else if (!mapped || mapped.length !== photos.length || mapped.some((entry) => !entry.url)) {
        issue("blocker", "task-photos-not-migrated", doc.path);
      } else {
        out.images = mapped.map((entry) => entry.url as string);
        out.imageUrls = mapped.map((entry) => entry.url as string);
        out.imagePaths = mapped.map((entry) => entry.path);
      }
    }
    // Legacy approval credited the bonus to the wallet immediately, matching the
    // current approval semantics (balance credited, not yet paid out).
    if (data.status === "approved" && data.isPaid === undefined && data.paidOut === undefined) {
      out.bonusCreditedToBalance = true;
      out.paidOut = false;
      totals.approvedTaskBonuses.count++;
      totals.approvedTaskBonuses.amount += num(out.cashBonusAwarded) ?? 0;
      if (ownerClosed) out.deletedOwnerTaskState = "credited_to_closed_account_balance";
    }
    if (ownerClosed) {
      // Customer details on the task are client business data and are kept.
      closeRecord(out, "employee_tasks", owner as string);
      closedStats.thirdPartyRecordsRetained++;
    }
    writes.push(finalize(doc.path, "transform", out));
  }

  // ─── role_requests ─────────────────────────────────────────────────────
  for (const doc of rootDocs("role_requests")) {
    const out: Doc = {...doc.data};
    fill(out, "requestedAt", doc.data.submittedAt);
    if (doc.data.status === "pending" && doc.data.requestedRole !== "employee") {
      issue("warning", "pending-unsupported-role-request", doc.path, String(doc.data.requestedRole));
    }
    if (str(doc.data.resumeDownloadUrl) && !decisions.copyResumes) {
      issue("info", "resume-left-in-source", doc.path);
    }
    const requester = str(doc.data.userId);
    if (requester && closed.has(requester)) closeRecord(out, "role_requests", requester);
    writes.push(finalize(doc.path, "transform", out));
  }

  // ─── app_settings / app_config ─────────────────────────────────────────
  for (const doc of rootDocs("app_settings")) writes.push(finalize(doc.path, "transform", {...doc.data}));
  if (!rootDocs("app_settings").some((doc) => idOf(doc.path) === "reward_settings")) {
    const legacy = rootDocs("app_config").find((doc) => idOf(doc.path) === "settings")?.data;
    const referral = num(legacy?.bugBucksPerReferral);
    if (referral === undefined || !Number.isSafeInteger(referral) || referral <= 0) {
      issue("blocker", "reward-settings-missing", "app_settings/reward_settings");
    } else {
      const settings: Doc = {referral_bug_bucks: referral, updated_by: "migration", updated_at: cutover};
      const taskBonus = num(legacy?.employeeTaskBonus);
      if (taskBonus !== undefined) settings.employee_cash_bonus = taskBonus;
      writes.push(finalize("app_settings/reward_settings", "derived", settings));
    }
  }

  // ─── unchanged copies, including every subcollection document ──────────
  for (const doc of snapshot.documents) {
    const root = rootOf(doc.path);
    const isRootDoc = doc.path.split("/").length === 2;
    const closedOwner = closed.has(str(doc.data.userId) ?? "") ||
      (root === "users" && closed.has(doc.path.split("/")[1]));
    if (closedOwner && (root === "notifications" || root === "users")) {
      closedStats.purgedRecords++; // Personal, non-financial: not migrated.
      continue;
    }
    if (closedOwner && root === "payout_requests" && isRootDoc) continue; // Written below.
    if (closedOwner && root === "transactions" && isRootDoc) {
      // Historical amounts and balances are unchanged; only the owner is pseudonymised.
      const out: Doc = {...doc.data, ownerAccountDeleted: true};
      pseudonymise(out, "transactions", doc.data.userId as string);
      writes.push(finalize(doc.path, "transform", out));
      continue;
    }
    if (COPIED.has(root) || (!isRootDoc && TRANSFORMED.has(root))) {
      writes.push(finalize(doc.path, "copy", {...doc.data}));
    }
  }

  // ─── accounts closed at the client's request ───────────────────────────
  // Each closed account gets a placeholder profile (status "deleted", no
  // personal data) so the app signs it out instead of creating a blank
  // customer profile. Its Auth user is excluded from import
  // (prepare-auth-import). Financial records are kept; every unresolved amount
  // is a blocker naming the decision that is needed.
  const closedTotals = {count: 0, legacyLedgerBalance: 0, pendingPayouts: {count: 0, amount: 0}};
  for (const account of closed.values()) {
    const uid = account.uid;
    const txs = txByUser.get(uid) ?? [];
    const ledgerBalance = round2(txs.reduce((sum, tx) => sum + (legacyDelta(tx.data) ?? 0), 0));
    const profile = users.get(uid);
    const profileBalances = Object.fromEntries(BALANCE_FIELDS
      .filter((field) => (num(profile?.[field]) ?? 0) !== 0)
      .map((field) => [field, num(profile?.[field]) as number]));
    const payouts = rootDocs("payout_requests").filter((doc) => str(doc.data.userId) === uid);
    const pending = payouts.filter((doc) => doc.data.status === "pending");
    const pendingAmount = round2(pending.reduce((sum, doc) => sum + (num(doc.data.amount) ?? 0), 0));
    const anchor = txs[0]?.path ?? pending[0]?.path ?? "closed-account";
    const pseudonym = closedAccountPseudonym(uid);
    closedTotals.count++;
    closedTotals.legacyLedgerBalance += ledgerBalance;
    closedTotals.pendingPayouts.count += pending.length;
    closedTotals.pendingPayouts.amount += pendingAmount;

    if (!str(account.decisionReference)) issue("blocker", "closed-account-decision-reference-missing", anchor);
    const hasBalance = ledgerBalance !== 0 || Object.keys(profileBalances).length > 0;
    if (hasBalance && (account.legacyBalanceDisposition === "unresolved" || account.legacyBalanceDisposition === "none")) {
      issue("blocker", "closed-account-balance-decision-required", anchor,
        `legacyLedgerBalance=${ledgerBalance} options=settled|written-off|retain-as-obligation`);
    }
    if (pending.length > 0 && (account.pendingPayoutDisposition === "unresolved" || account.pendingPayoutDisposition === "none")) {
      issue("blocker", "closed-account-payout-decision-required", pending[0].path,
        `pending=${pending.length} amount=${pendingAmount} options=paid-externally|cancelled|retain-as-obligation`);
    }
    const needsReference = (hasBalance && account.legacyBalanceDisposition === "settled") ||
      (pending.length > 0 && account.pendingPayoutDisposition === "paid-externally");
    if (needsReference && !str(account.settlementReference)) {
      issue("blocker", "closed-account-settlement-reference-missing", anchor);
    }
    if (account.legacyBalanceDisposition === "retain-as-obligation" ||
        account.pendingPayoutDisposition === "retain-as-obligation") {
      issue("warning", "closed-account-obligation-retained", anchor);
    }
    if (txs.length === 0 && payouts.length === 0 && !profile) {
      issue("warning", "closed-account-has-no-records", "closed-account");
    }

    // Payouts: record the decision; bank details are kept only while a payout
    // remains payable.
    for (const doc of payouts) {
      const out: Doc = {...doc.data};
      const isPending = doc.data.status === "pending";
      const disposition = account.pendingPayoutDisposition;
      if (isPending && disposition === "paid-externally") {
        out.legacyStatus = doc.data.status;
        out.status = "paid_externally";
        out.settlementReference = account.settlementReference ?? null;
        out.settlementRecordedAt = cutover;
      } else if (isPending && disposition === "cancelled") {
        out.legacyStatus = doc.data.status;
        out.status = "cancelled";
        out.payable = false;
        out.cancellationReference = account.decisionReference;
        out.cancelledAt = cutover;
        writes.push(finalize(`audit_logs/migration_payout_cancelled_${idOf(doc.path)}`, "derived", {
          action: "PAYOUT_CANCELLED", payoutRequestId: idOf(doc.path), subject: pseudonym,
          amount: num(doc.data.amount) ?? 0, amountUnit: LEGACY_UNIT, previousStatus: doc.data.status,
          decisionReference: account.decisionReference, decisionDate: account.decisionDate ?? null,
          effect: "Not payable. No balance or ledger change.", timestamp: cutover,
        }));
      }
      if (isPending && (disposition === "retain-as-obligation" || disposition === "unresolved")) {
        out.ownerAccountDeleted = true;
        out.obligationRetained = disposition === "retain-as-obligation";
        pseudonymise(out, "payout_requests", uid);
      } else {
        closeRecord(out, "payout_requests", uid);
      }
      writes.push(finalize(doc.path, "transform", out));
    }

    const placeholder: Doc = {
      status: "deleted", isDeleted: true, deletedAt: cutover, deletedBy: "client-request",
      deletedSource: "admin", deletionReason: account.closureReason ?? "account-closed-at-client-request",
      accountDeletionStatus: "completed", needsVerification: false,
      bugBucks: 0, cashBonusBalance: 0, profileInSource: profile !== undefined,
      closedAccount: {
        decisionReference: account.decisionReference,
        legacyBalanceDisposition: account.legacyBalanceDisposition,
        pendingPayoutDisposition: account.pendingPayoutDisposition,
        settlementReference: account.settlementReference ?? null,
        legacyLedgerBalance: ledgerBalance,
        amountUnit: LEGACY_UNIT,
        legacyProfileBalances: profileBalances,
        pendingPayoutAmount: pendingAmount,
        authAccount: "excluded-from-import",
        decisionDate: account.decisionDate ?? null,
      },
    };
    if (hasBalance && account.legacyBalanceDisposition === "written-off") {
      // Recorded only: historical ledger amounts stay unchanged and no credit
      // or debit entry is created for anyone.
      (placeholder.closedAccount as Doc).writeOff = {amount: ledgerBalance, amountUnit: LEGACY_UNIT, recordedAt: cutover};
      writes.push(finalize(`audit_logs/migration_balance_write_off_${pseudonym.slice(-16)}`, "derived", {
        action: "BALANCE_WRITTEN_OFF", subject: pseudonym, amount: ledgerBalance, amountUnit: LEGACY_UNIT,
        composition: Object.fromEntries([...txs.reduce((acc, tx) => acc.set(String(tx.data.type),
          (acc.get(String(tx.data.type)) ?? 0) + (legacyDelta(tx.data) ?? 0)), new Map<string, number>())]),
        ledgerEntries: txs.length, decisionReference: account.decisionReference,
        decisionDate: account.decisionDate ?? null,
        effect: "Recorded only. Historical ledger amounts unchanged; no credit created.", timestamp: cutover,
      }));
    }
    writes.push(finalize(`users/${pseudonym}`, profile ? "transform" : "derived", placeholder));
    const ownedBy = (name: string, field: (data: Doc) => string | undefined) =>
      rootDocs(name).filter((doc) => field(doc.data) === uid).length;
    writes.push(finalize(`audit_logs/migration_account_closure_${pseudonym.slice(-16)}`, "derived", {
      action: "ACCOUNT_CLOSED_AT_CLIENT_REQUEST",
      subject: pseudonym,
      decisionDate: account.decisionDate ?? null,
      decisionReference: account.decisionReference,
      legacyBalanceDisposition: account.legacyBalanceDisposition,
      pendingPayoutDisposition: account.pendingPayoutDisposition,
      settlementReference: account.settlementReference ?? null,
      amounts: {legacyLedgerBalance: ledgerBalance, pendingPayoutAmount: pendingAmount, amountUnit: LEGACY_UNIT},
      records: {
        ledgerEntriesRetained: txs.length,
        payoutRequests: payouts.length,
        referralsRedacted: ownedBy("referrals", referralOwner),
        tasksRedacted: ownedBy("employee_tasks", taskOwner),
        roleRequestsRedacted: ownedBy("role_requests", (data) => str(data.userId)),
        notificationsNotMigrated: ownedBy("notifications", (data) => str(data.userId)),
      },
      authAccount: "excluded-from-import",
      timestamp: cutover,
    }));
  }

  // ─── migration audit entry ─────────────────────────────────────────────
  const counts: Record<string, number> = {};
  for (const [root, docs] of byRoot) counts[root] = docs.length;
  const summary = {
    sourceCounts: counts,
    roles: roleCounts,
    statuses: statusCounts,
    legacyBalanceTotals: Object.fromEntries(Object.entries(totals.legacy).map(([key, value]) => [key, round2(value)])),
    openingBugBucksTotal: round2(totals.openingBugBucks),
    openingCashBonusTotal: round2(totals.openingCashBonus),
    pendingPayouts: {count: totals.pendingPayouts.count, amount: round2(totals.pendingPayouts.amount)},
    pendingReferralRewards: {count: totals.pendingReferralRewards.count, amount: round2(totals.pendingReferralRewards.amount)},
    approvedTaskBonusesCreditedToBalance: {
      count: totals.approvedTaskBonuses.count, amount: round2(totals.approvedTaskBonuses.amount),
    },
    legacyLedgerMismatches: totals.ledgerMismatches,
    closedAccounts: {
      count: closedTotals.count,
      legacyLedgerBalance: round2(closedTotals.legacyLedgerBalance),
      pendingPayouts: {count: closedTotals.pendingPayouts.count, amount: round2(closedTotals.pendingPayouts.amount)},
      ...closedStats,
    },
    excludedAccounts: {count: excluded.size},
    referralRewardsCredited: {count: rewardTotals.count, amount: rewardTotals.amount},
    finalBugBucksTotal: round2(totals.openingBugBucks + rewardTotals.amount),
    profileDefaults: profileStats,
    ownerProfileMissing: {
      legacyLedger: {...stranded.legacyLedger, balance: round2(stranded.legacyLedger.balance)},
      currentLedger: {...stranded.currentLedger, amount: round2(stranded.currentLedger.amount)},
      pendingPayouts: {...stranded.pendingPayouts, amount: round2(stranded.pendingPayouts.amount)},
    },
  } satisfies Record<string, Encoded>;
  writes.push(finalize(`audit_logs/migration_import_${snapshot.snapshotId.slice(0, 16)}`, "derived", {
    action: "MIGRATION_IMPORT",
    sourceProject: snapshot.sourceProject,
    snapshotId: snapshot.snapshotId,
    snapshotTakenAt: snapshot.takenAt,
    summary,
    timestamp: cutover,
  }));

  // ─── excluded sign-ins and identifier self-check ────────────────────────
  // A UID counts as present only as a whole token, e.g. "users/{uid}" or a field
  // value, never as a substring of an unrelated word.
  const mentions = (text: string, uid: string) =>
    new RegExp(`(^|[^A-Za-z0-9])${uid.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}([^A-Za-z0-9]|$)`).test(text);
  for (const account of excluded.values()) {
    if (!str(account.decisionReference)) issue("blocker", "excluded-account-decision-reference-missing", "excluded-account");
    const referenced = snapshot.documents.some((doc) =>
      mentions(doc.path, account.uid) || mentions(stableStringify(doc.data), account.uid));
    if (referenced) issue("blocker", "excluded-account-has-records", "excluded-account");
  }
  for (const uid of [...closed.keys(), ...excluded.keys()]) {
    for (const write of writes) {
      if (mentions(write.path, uid) || mentions(stableStringify(write.data), uid)) {
        issue("blocker", "closed-account-identifier-remaining", rootOf(write.path));
      }
    }
  }

  const seen = new Set<string>();
  for (const write of writes) {
    if (seen.has(write.path)) issue("blocker", "duplicate-target-path", write.path);
    seen.add(write.path);
  }
  return {snapshotId: snapshot.snapshotId, writes, issues, summary};
}

export function issueCounts(issues: Issue[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const item of issues) {
    const key = `${item.severity}:${item.code}`;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}
