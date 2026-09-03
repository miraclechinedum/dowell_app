import {applicationDefault, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

// Read-only inventory. Missing isDeleted is intentionally treated as active.
// This script performs no writes and is not invoked by CI or deployment.
const COLLECTIONS = [
  "users", "referrals", "employee_tasks", "employee_cashouts",
  "role_requests", "notifications",
];

initializeApp({credential: applicationDefault()});
const db = getFirestore();

async function main() {
  console.log("SOFT DELETE READINESS DRY RUN (no writes)");
  for (const collection of COLLECTIONS) {
    const snapshot = await db.collection(collection).get();
    let missing = 0;
    let active = 0;
    let deleted = 0;
    for (const document of snapshot.docs) {
      const value = document.get("isDeleted");
      if (value === true) deleted++;
      else {
        active++;
        if (value == null) missing++;
      }
    }
    console.log({collection, total: snapshot.size, active, deleted, missing});
  }
}

main().catch((error) => {
  console.error("Soft-delete readiness audit failed", error);
  process.exitCode = 1;
});
