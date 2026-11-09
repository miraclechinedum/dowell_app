import {readFileSync} from "node:fs";
import {join} from "node:path";
import {applicationDefault, initializeApp} from "firebase-admin/app";
import {UserRecord, getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {canonicalRoleClaims} from "../../src/role-claims.js";
import {
  parseArgs, pathArg, readPrivateJson, repoRoot, requireApprovalForApply, sha256, writeTarget,
} from "./common.js";
import {Decisions} from "./plan.js";

// Provisions the separate client-owned admin account in the target project.
// Dry run by default. Never takes over an existing identity and never handles a
// password: the account is created without one, and Firebase emails a
// password-setup (reset) link directly to the approved inbox. No password or
// reset token passes through this process or its output.
//
// Usage:
//   node lib/scripts/migration/provision-client-admin.js --target=dowell-pest-control-prod \
//     [--decisions=…] [--apply --confirm-target=dowell-pest-control-prod] [--send-password-setup-email]

function webApiKey(project: string): string {
  // The Android config for the target project holds its public Web API key.
  const config = JSON.parse(readFileSync(join(repoRoot(), "android/app/google-services.json"), "utf8"));
  if (config.project_info?.project_id !== project) {
    throw new Error(`android/app/google-services.json is not configured for ${project}.`);
  }
  const key = config.client?.[0]?.api_key?.[0]?.current_key;
  if (typeof key !== "string") throw new Error("Web API key not found in google-services.json.");
  return key;
}

async function main(): Promise<void> {
  const args = parseArgs();
  const {project, apply} = writeTarget(args);
  const decisions = readPrivateJson<Decisions>(pathArg(args, "decisions", "decisions.json"));
  const client = decisions.clientAdmin;
  if (!client?.email) throw new Error("decisions.clientAdmin.email is required.");
  requireApprovalForApply(apply, decisions, {clientAdmin: true});
  const sendEmail = args.get("send-password-setup-email") === true;
  const app = initializeApp({credential: applicationDefault(), projectId: project}, "client-admin");
  const auth = getAuth(app);
  const db = getFirestore(app);
  const steps: Record<string, string> = {};

  let user: UserRecord | null = await auth.getUserByEmail(client.email).catch((error) => {
    if (error.code === "auth/user-not-found") return null;
    throw error;
  });
  if (user) {
    const profile = await db.doc(`users/${user.uid}`).get();
    if (profile.get("provisionedClientAdmin") !== true) {
      throw new Error("An account with this email exists but was not provisioned by this tool. Stop and review.");
    }
    steps.account = "existing-provisioned";
  } else if (apply) {
    user = await auth.createUser({email: client.email, emailVerified: false, disabled: false});
    steps.account = "created-without-password";
  } else {
    steps.account = "would-create-without-password";
  }

  if (user) {
    const profileRef = db.doc(`users/${user.uid}`);
    const profile = await profileRef.get();
    if (!profile.exists) {
      if (apply) {
        await profileRef.create({
          email: client.email, displayName: "Dowell Pest Control Admin", role: "admin",
          status: "active", needsVerification: false, isDeleted: false,
          bugBucks: 0, cashBonusBalance: 0, provisionedClientAdmin: true,
          claimSyncStatus: "pending",
          createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
        });
      }
      steps.profile = apply ? "created" : "would-create";
    } else {
      steps.profile = "existing";
    }
    const claims = canonicalRoleClaims("admin", user.customClaims ?? {});
    if (user.customClaims?.admin === true && user.customClaims?.role === "admin") {
      steps.claims = "unchanged";
    } else if (apply) {
      await auth.setCustomUserClaims(user.uid, claims);
      await profileRef.update({claimSyncStatus: "synchronized", updatedAt: FieldValue.serverTimestamp()});
      // Same audit shape as the setUserRole Function, with a deterministic ID.
      await db.doc(`audit_logs/client_admin_provisioned_${sha256(user.uid).slice(0, 16)}`).set({
        action: "ROLE_CHANGE", actorUid: "migration-operator", targetUid: user.uid,
        previousRole: null, newRole: "admin", reason: "Client-owned admin account provisioned",
        claimSyncStatus: "synchronized", timestamp: FieldValue.serverTimestamp(),
      }, {merge: true});
      steps.claims = "set-admin";
    } else {
      steps.claims = "would-set-admin";
    }
  } else {
    steps.profile = "would-create";
    steps.claims = "would-set-admin";
  }

  // Firebase sends the email itself; the reset token never reaches this process.
  if (sendEmail && apply && user) {
    const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${webApiKey(project)}`,
      {method: "POST", headers: {"Content-Type": "application/json"},
        body: JSON.stringify({requestType: "PASSWORD_RESET", email: client.email})},
    );
    steps.passwordSetupEmail = response.ok ? "sent-to-approved-inbox" : `failed-http-${response.status}`;
  } else {
    steps.passwordSetupEmail = sendEmail ? "would-send" : "not-requested";
  }

  console.log(JSON.stringify({mode: apply ? "apply" : "dry-run", target: project, steps}, null, 2));
  if (steps.passwordSetupEmail.startsWith("failed")) process.exitCode = 1;
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
