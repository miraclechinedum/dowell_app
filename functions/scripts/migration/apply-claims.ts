import {applicationDefault, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {
  parseArgs, readPrivateJson, requireApprovalForApply, stringArg, writePrivateJson, writeTarget,
} from "./common.js";
import {POLICY_HELD_REASONS, approvedAdminSet, claimDecision, isClosedProfile, sameRoleClaims} from "./claims-policy.js";
import {Decisions} from "./plan.js";

// Sets role custom claims in the target project from migrated users/{uid}.role.
// Dry run by default. Unsupported roles and unapproved admins are held.
// Tokens are not revoked: no sessions exist in the target before cutover.
//
// Usage:
//   node lib/scripts/migration/apply-claims.js --decisions=… --target=… --report=/abs/claims.json \
//     [--apply --confirm-target=…]

async function main(): Promise<void> {
  const args = parseArgs();
  const {project, apply} = writeTarget(args);
  const decisions = readPrivateJson<Decisions>(stringArg(args, "decisions") as string);
  requireApprovalForApply(apply, decisions);
  const app = initializeApp({credential: applicationDefault(), projectId: project}, "claims-migration");
  const auth = getAuth(app);
  const profiles = await getFirestore(app).collection("users").get();
  const approvedAdmins = approvedAdminSet(decisions, profiles.docs.map((doc) => ({id: doc.id, ...doc.data()})));
  const rows: {uid: string; outcome: string}[] = [];
  for (const profile of profiles.docs) {
    if (isClosedProfile(profile.data())) {
      rows.push({uid: profile.id, outcome: "skipped:closed-account"});
      continue;
    }
    let user;
    try {
      user = await auth.getUser(profile.id);
    } catch {
      rows.push({uid: profile.id, outcome: "held:auth-user-missing"});
      continue;
    }
    const existing = user.customClaims ?? {};
    const decision = claimDecision(profile.id, profile.get("role"), existing, approvedAdmins, profile.get("status"));
    if (decision.kind === "held") {
      // A held account must not keep an elevated claim from any earlier run.
      if (existing.admin === true || existing.employee === true) {
        rows.push({uid: profile.id, outcome: "error:held-account-has-elevated-claim"});
        continue;
      }
      rows.push({uid: profile.id, outcome: `held:${decision.reason}`});
    } else if (sameRoleClaims(existing, decision.claims)) {
      rows.push({uid: profile.id, outcome: "unchanged"});
    } else {
      if (apply) await auth.setCustomUserClaims(profile.id, decision.claims);
      rows.push({uid: profile.id, outcome: `${apply ? "set" : "would-set"}:${String(decision.claims.role)}`});
    }
  }
  for (const uid of decisions.approvedAdminUids) {
    if (!profiles.docs.some((doc) => doc.id === uid && doc.get("role") === "admin")) {
      rows.push({uid, outcome: "held:approved-admin-without-admin-profile"});
    }
  }

  writePrivateJson(stringArg(args, "report") as string, {mode: apply ? "apply" : "dry-run", target: project, rows});
  const tally = rows.reduce<Record<string, number>>((acc, row) => {
    acc[row.outcome] = (acc[row.outcome] ?? 0) + 1;
    return acc;
  }, {});
  console.log(JSON.stringify({mode: apply ? "apply" : "dry-run", target: project, outcomes: tally}, null, 2));
  const unexpected = rows.filter((row) => row.outcome.startsWith("error") ||
    (row.outcome.startsWith("held:") && !POLICY_HELD_REASONS.has(row.outcome.slice(5))));
  if (unexpected.length > 0) process.exitCode = 2;
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
