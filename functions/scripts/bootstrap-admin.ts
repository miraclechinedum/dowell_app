import {applicationDefault, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {canonicalRoleClaims, isCanonicalRole} from "../src/role-claims.js";
import {assertInitializedProject, resolveLegacyTarget} from "./legacy-target.js";

async function main(): Promise<void> {
  // Target and arguments are validated before Firebase is initialized.
  const run = resolveLegacyTarget(process.argv.slice(2), process.env, {allowPositionals: true});
  const app = initializeApp({credential: applicationDefault(), projectId: run.project});
  assertInitializedProject(app.options.projectId, run.project);
  const apply = run.apply;
  const uids = run.positionals.map((uid) => uid.trim()).filter(Boolean);
  if (uids.length === 0) {
    throw new Error("Supply one or more explicit Firebase Auth UIDs.");
  }

  for (const uid of uids) {
    const [user, profile] = await Promise.all([
      getAuth().getUser(uid), getFirestore().collection("users").doc(uid).get(),
    ]);
    const role = profile.get("role");
    if (!profile.exists || !isCanonicalRole(role)) {
      console.log(JSON.stringify({uid, status: "manual-review", firestoreRole: role ?? null}));
      continue;
    }
    const current = user.customClaims ?? {};
    const proposed = canonicalRoleClaims(role, current);
    console.log(JSON.stringify({uid, mode: apply ? "apply" : "dry-run", current, proposed}));
    if (apply) await getAuth().setCustomUserClaims(uid, proposed);
  }
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
