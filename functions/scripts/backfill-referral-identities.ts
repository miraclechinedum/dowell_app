import {createHash} from "node:crypto";
import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

initializeApp();

function hash(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

async function main(): Promise<void> {
  const apply = process.argv.includes("--apply");
  const counts = {scanned: 0, unchanged: 0, wouldCreate: 0, ambiguous: 0, errors: 0};
  const db = getFirestore();
  const referrals = await db.collection("referrals").get();
  const proposed = new Map<string, {customerId: string; referralId: string}>();
  for (const referral of referrals.docs) {
    counts.scanned++;
    try {
      const data = referral.data();
      const uid = typeof data.customerId === "string" ? data.customerId : "";
      const email = typeof data.referralEmail === "string" ? data.referralEmail.trim().toLowerCase() : "";
      const phone = typeof data.referralPhone === "string" ? data.referralPhone.replace(/\D/g, "") : "";
      if (!uid || !email || phone.length < 7) {
        counts.ambiguous++;
        console.log(JSON.stringify({referralId: referral.id, status: "manual-review", reason: "missing-identity"}));
        continue;
      }
      const ids = [hash(`${uid}:email:${email}`), hash(`${uid}:phone:${phone}`)];
      const conflict = ids.some((id) => {
        const prior = proposed.get(id);
        return prior != null && prior.referralId !== referral.id;
      });
      if (conflict) {
        counts.ambiguous++;
        console.log(JSON.stringify({referralId: referral.id, status: "manual-review", reason: "duplicate-legacy-identity"}));
        continue;
      }
      ids.forEach((id) => proposed.set(id, {customerId: uid, referralId: referral.id}));
    } catch (error) {
      counts.errors++;
      console.error(JSON.stringify({referralId: referral.id, error: String(error)}));
    }
  }
  for (const [id, value] of proposed) {
    const ref = db.collection("referral_identities").doc(id);
    if ((await ref.get()).exists) {
      counts.unchanged++;
    } else {
      counts.wouldCreate++;
      if (apply) await ref.create({...value, createdAt: FieldValue.serverTimestamp(), source: "legacy-backfill"});
    }
  }
  console.log(JSON.stringify({...counts, mode: apply ? "apply" : "dry-run"}));
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
