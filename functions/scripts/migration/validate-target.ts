import {applicationDefault, initializeApp} from "firebase-admin/app";
import {Auth, UserRecord, getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {
  SOURCE_PROJECT, WRITABLE_TARGETS, parseArgs, readPrivateJson, sha256, stringArg, writePrivateJson,
} from "./common.js";
import {POLICY_HELD_REASONS, approvedAdminSet, claimDecision, isClosedProfile, sameRoleClaims} from "./claims-policy.js";
import {Decisions, Snapshot, StorageMap, buildPlan} from "./plan.js";

// READ-ONLY on both projects. Validates a migrated target against the snapshot
// plan and the source Auth users. Prints aggregate results only; per-record
// findings go to the private report. Exit code 2 when any check fails.
//
// Usage:
//   node lib/scripts/migration/validate-target.js --snapshot=… --decisions=… --storage-map=… \
//     --target=dowell-pest-control-prod --report=/abs/validation.json

async function listAll(auth: Auth): Promise<Map<string, UserRecord>> {
  const users = new Map<string, UserRecord>();
  let pageToken: string | undefined;
  do {
    const page = await auth.listUsers(1000, pageToken);
    page.users.forEach((user) => users.set(user.uid, user));
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

function fingerprint(user: UserRecord): string {
  return sha256(JSON.stringify([
    user.email?.toLowerCase() ?? null, user.emailVerified, user.disabled,
    user.providerData.map((provider) => provider.providerId).sort(),
    Boolean(user.passwordHash), user.metadata.creationTime,
  ]));
}

async function main(): Promise<void> {
  const args = parseArgs();
  const target = stringArg(args, "target") as string;
  if (!WRITABLE_TARGETS.has(target)) throw new Error(`Unknown target ${target}.`);
  const snapshot = readPrivateJson<Snapshot>(stringArg(args, "snapshot") as string);
  const decisions = readPrivateJson<Decisions>(stringArg(args, "decisions") as string);
  const storageMap = readPrivateJson<StorageMap>(stringArg(args, "storage-map") as string);
  const plan = buildPlan(snapshot, decisions, storageMap);

  const targetApp = initializeApp({credential: applicationDefault(), projectId: target}, "validate-target");
  const sourceApp = initializeApp({credential: applicationDefault(), projectId: SOURCE_PROJECT}, "validate-source");
  const db = getFirestore(targetApp);
  const findings: {check: string; ref: string}[] = [];
  const fail = (check: string, ref: string) => findings.push({check, ref});

  // 1. Every planned document exists with the planned content.
  for (const write of plan.writes) {
    const doc = await db.doc(write.path).get();
    if (!doc.exists) fail("document-missing", write.path);
    else if (doc.get("migration.contentHash") !== write.contentHash) fail("document-content-differs", write.path);
  }

  // 2. Balances: each profile's Bug Bucks equal the last migration ledger entry
  // (opening balance, then any authorised reward credits); cash bonus equals the
  // opening cash entry.
  const profiles = await db.collection("users").get();
  const migrationLedger = await db.collection("bugbucks_transactions")
    .where("type", "in", ["migration_opening_balance", "migration_referral_reward"]).get();
  const lastBalance = new Map<string, {at: number; balance: number}>();
  for (const entry of migrationLedger.docs) {
    const at = entry.get("createdAt")?.toMillis?.() ?? 0;
    const current = lastBalance.get(entry.get("userId"));
    if (!current || at > current.at) lastBalance.set(entry.get("userId"), {at, balance: entry.get("balanceAfter")});
  }
  for (const profile of profiles.docs) {
    const uid = profile.id;
    const cash = await db.doc(`cash_bonus_transactions/migration_opening_${uid}`).get();
    const bugBucks = profile.get("bugBucks") ?? 0;
    const cashBonus = profile.get("cashBonusBalance") ?? 0;
    if ((lastBalance.get(uid)?.balance ?? 0) !== bugBucks) fail("bug-bucks-ledger-mismatch", profile.ref.path);
    if (Math.abs((cash.exists ? cash.get("amount") : 0) - cashBonus) > 0.005) {
      fail("cash-bonus-opening-mismatch", profile.ref.path);
    }
  }
  if (!(await db.doc("app_settings/reward_settings").get()).exists) fail("reward-settings-missing", "app_settings/reward_settings");

  // 3. Auth parity by UID, and profile coverage (prevents blank-profile creation).
  const [sourceUsers, targetUsers] = await Promise.all([
    listAll(getAuth(sourceApp)), listAll(getAuth(targetApp)),
  ]);
  // Closed accounts must NOT exist in the target; the client admin is the only
  // expected account that has no source counterpart.
  const closed = new Set([
    ...(decisions.closedAccounts ?? []).map((account) => account.uid),
    ...(decisions.excludedAccounts ?? []).map((account) => account.uid),
  ]);
  const approvedAdmins = approvedAdminSet(decisions, profiles.docs.map((doc) => ({id: doc.id, ...doc.data()})));
  const clientAdminUids = new Set([...approvedAdmins].filter((uid) => !decisions.approvedAdminUids.includes(uid)));
  for (const [uid, user] of sourceUsers) {
    const migrated = targetUsers.get(uid);
    if (closed.has(uid)) {
      if (migrated) fail("closed-account-auth-present", uid);
    } else if (!migrated) fail("auth-user-missing", uid);
    else if (fingerprint(user) !== fingerprint(migrated)) fail("auth-user-differs", uid);
  }
  for (const uid of targetUsers.keys()) {
    if (!sourceUsers.has(uid) && !clientAdminUids.has(uid)) fail("auth-user-unexpected", uid);
  }
  const profileIds = new Set(profiles.docs.map((doc) => doc.id));
  for (const uid of targetUsers.keys()) if (!profileIds.has(uid)) fail("auth-user-without-profile", uid);
  for (const profile of profiles.docs) {
    const isClosed = isClosedProfile(profile.data());
    if (closed.has(profile.id)) fail("closed-or-excluded-account-profile-present", profile.id);
    if (!targetUsers.has(profile.id) && !isClosed) fail("profile-without-auth-user", profile.id);
  }

  // 4. Claims match the approved policy. No account outside the approved
  // admin set may hold an admin claim, profile or not.
  const policyHeld: Record<string, number> = {};
  for (const [uid, user] of targetUsers) {
    if (user.customClaims?.admin === true && !approvedAdmins.has(uid)) fail("unapproved-admin-claim", uid);
  }
  for (const profile of profiles.docs) {
    const user = targetUsers.get(profile.id);
    if (!user || isClosedProfile(profile.data())) continue;
    const claims = user.customClaims ?? {};
    const decision = claimDecision(profile.id, profile.get("role"), claims, approvedAdmins, profile.get("status"));
    if (decision.kind === "held") {
      if (!POLICY_HELD_REASONS.has(decision.reason)) fail(`claims-held:${decision.reason}`, profile.id);
      else policyHeld[decision.reason] = (policyHeld[decision.reason] ?? 0) + 1;
      if (claims.admin === true || claims.employee === true) fail("held-account-has-elevated-claim", profile.id);
    } else if (!sameRoleClaims(claims, decision.claims)) fail("claims-mismatch", profile.id);
  }

  const tally = findings.reduce<Record<string, number>>((acc, item) => {
    acc[item.check] = (acc[item.check] ?? 0) + 1;
    return acc;
  }, {});
  writePrivateJson(stringArg(args, "report") as string, {target, snapshotId: plan.snapshotId, findings});
  console.log(JSON.stringify({
    target, snapshotId: plan.snapshotId,
    counts: {
      plannedDocuments: plan.writes.length, sourceAuthUsers: sourceUsers.size,
      targetAuthUsers: targetUsers.size, targetProfiles: profiles.size,
    },
    summary: plan.summary,
    claimsWithheldByPolicy: policyHeld,
    failures: tally,
    result: findings.length === 0 ? "PASS" : "FAIL",
  }, null, 2));
  if (findings.length > 0) process.exitCode = 2;
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
