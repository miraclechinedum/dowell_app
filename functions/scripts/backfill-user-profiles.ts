import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

initializeApp();

async function main(): Promise<void> {
  const apply = process.argv.includes("--apply");
  const counts = {scanned: 0, unchanged: 0, wouldUpdate: 0, ambiguous: 0, errors: 0};
  const users = await getFirestore().collection("users").get();
  for (const profile of users.docs) {
    counts.scanned++;
    try {
      const data = profile.data();
      const update: Record<string, unknown> = {};
      const knownUnsafe = data.status === "pending" || data.status === "deactivated" ||
        data.status === "blocked" || data.needsVerification === true || data.requestedRole != null;
      if (data.status == null) {
        if (knownUnsafe) {
          counts.ambiguous++;
          console.log(JSON.stringify({uid: profile.id, status: "manual-review", reason: "missing-status"}));
          continue;
        }
        update.status = "active";
      }
      if (data.needsVerification == null) {
        if (data.status === "pending" || data.requestedRole != null) {
          update.needsVerification = true;
        } else if (data.status === "active" || update.status === "active") {
          update.needsVerification = false;
        } else {
          counts.ambiguous++;
          console.log(JSON.stringify({uid: profile.id, status: "manual-review", reason: "missing-verification"}));
          continue;
        }
      }
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
