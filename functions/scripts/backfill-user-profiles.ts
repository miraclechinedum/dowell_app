import {applicationDefault, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {assertInitializedProject, resolveLegacyTarget} from "./legacy-target.js";
import {profileDefaults} from "./profile-defaults.js";

async function main(): Promise<void> {
  // Target and arguments are validated before Firebase is initialized.
  const run = resolveLegacyTarget(process.argv.slice(2), process.env);
  const app = initializeApp({credential: applicationDefault(), projectId: run.project});
  assertInitializedProject(app.options.projectId, run.project);
  const apply = run.apply;
  const counts = {scanned: 0, unchanged: 0, wouldUpdate: 0, ambiguous: 0, errors: 0};
  const users = await getFirestore().collection("users").get();
  for (const profile of users.docs) {
    counts.scanned++;
    try {
      const defaults = profileDefaults(profile.data());
      if (defaults.kind === "review") {
        counts.ambiguous++;
        console.log(JSON.stringify({uid: profile.id, status: "manual-review", reason: defaults.reason}));
        continue;
      }
      const update = defaults.update;
      if (Object.keys(update).length === 0) {
        counts.unchanged++;
      } else {
        counts.wouldUpdate++;
        console.log(JSON.stringify({uid: profile.id, mode: apply ? "apply" : "dry-run", update}));
        if (apply) await profile.ref.update(update);
      }
    } catch (error) {
      counts.errors++;
      console.error(JSON.stringify({uid: profile.id, error: String(error)}));
    }
  }
  console.log(JSON.stringify(counts));
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
