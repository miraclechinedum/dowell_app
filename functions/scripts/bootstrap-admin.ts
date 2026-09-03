import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {canonicalRoleClaims, isCanonicalRole} from "../src/role-claims.js";

initializeApp();

async function main(): Promise<void> {
  const apply = process.argv.includes("--apply");
  const uids = process.argv.slice(2).filter((arg) => !arg.startsWith("--"))
    .map((uid) => uid.trim()).filter(Boolean);
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
