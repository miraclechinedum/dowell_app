import {applicationDefault, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {
  SCHEMA_TAG, SOURCE_PROJECT, parseArgs, readPrivateJson, requireApprovalForApply, stringArg,
  writePrivateJson, writeTarget,
} from "./common.js";
import {decodeValue} from "./firestore-codec.js";
import {Decisions, Snapshot, StorageMap, buildPlan, issueCounts} from "./plan.js";

// Applies the migration plan to the client project (dowell-pest-control-prod). Dry run by
// default. Never deletes. Idempotent:
// - missing target document            → created
// - same migration contentHash         → unchanged
// - older migrated version             → conflict unless --allow-update
// - document not written by migration  → conflict, never overwritten
//
// Usage:
//   node lib/scripts/migration/migrate-firestore.js --snapshot=… --decisions=… \
//     --storage-map=… --target=dowell-pest-control-prod --report=/abs/report.json \
//     [--apply --confirm-target=dowell-pest-control-prod] [--allow-update]

async function main(): Promise<void> {
  const args = parseArgs();
  const {project, apply} = writeTarget(args);
  const snapshot = readPrivateJson<Snapshot>(stringArg(args, "snapshot") as string);
  const decisions = readPrivateJson<Decisions>(stringArg(args, "decisions") as string);
  const storageMap = readPrivateJson<StorageMap>(stringArg(args, "storage-map") as string);
  const reportPath = stringArg(args, "report") as string;
  const allowUpdate = args.get("allow-update") === true;
  if (snapshot.sourceProject !== SOURCE_PROJECT) throw new Error("Snapshot is not from the legacy project.");
  if (storageMap.bucket !== `${project}.firebasestorage.app`) {
    throw new Error("Storage map was produced for a different target bucket.");
  }

  const plan = buildPlan(snapshot, decisions, storageMap);
  const blockers = plan.issues.filter((item) => item.severity === "blocker");
  requireApprovalForApply(apply, decisions);
  if (apply && blockers.length > 0) {
    throw new Error(`Refusing to apply: blockers=${blockers.length}.`);
  }

  const app = initializeApp({credential: applicationDefault(), projectId: project}, "firestore-migration");
  const db = getFirestore(app);
  const outcomes: {path: string; outcome: string}[] = [];
  const pending: {path: string; data: unknown; mode: "create" | "set"}[] = [];

  for (const write of plan.writes) {
    const existing = await db.doc(write.path).get();
    if (!existing.exists) {
      outcomes.push({path: write.path, outcome: apply ? "created" : "would-create"});
      pending.push({path: write.path, data: decodeValue(write.data, db), mode: "create"});
      continue;
    }
    const marker = existing.get("migration") as {schema?: string; contentHash?: string} | undefined;
    if (marker?.contentHash === write.contentHash) {
      outcomes.push({path: write.path, outcome: "unchanged"});
    } else if (marker?.schema === SCHEMA_TAG && allowUpdate) {
      outcomes.push({path: write.path, outcome: apply ? "updated" : "would-update"});
      pending.push({path: write.path, data: decodeValue(write.data, db), mode: "set"});
    } else {
      outcomes.push({path: write.path, outcome: marker?.schema === SCHEMA_TAG ?
        "conflict-stale-migrated-version" : "conflict-not-written-by-migration"});
    }
  }

  const conflicts = outcomes.filter((item) => item.outcome.startsWith("conflict")).length;
  if (apply && conflicts > 0) {
    throw new Error(`Refusing to apply: ${conflicts} conflicting target document(s). Review the report.`);
  }
  if (apply) {
    for (let offset = 0; offset < pending.length; offset += 400) {
      const batch = db.batch();
      for (const item of pending.slice(offset, offset + 400)) {
        const ref = db.doc(item.path);
        if (item.mode === "create") batch.create(ref, item.data as FirebaseFirestore.DocumentData);
        else batch.set(ref, item.data as FirebaseFirestore.DocumentData);
      }
      await batch.commit();
    }
  }

  const tally = outcomes.reduce<Record<string, number>>((acc, item) => {
    acc[item.outcome] = (acc[item.outcome] ?? 0) + 1;
    return acc;
  }, {});
  writePrivateJson(reportPath, {
    mode: apply ? "apply" : "dry-run", target: project, snapshotId: plan.snapshotId,
    summary: plan.summary, issues: plan.issues, outcomes,
  });
  console.log(JSON.stringify({
    mode: apply ? "apply" : "dry-run", target: project, snapshotId: plan.snapshotId,
    outcomes: tally, blockers: blockers.length, issueCounts: issueCounts(plan.issues),
  }, null, 2));
  if (blockers.length > 0 || conflicts > 0) process.exitCode = 2;
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
