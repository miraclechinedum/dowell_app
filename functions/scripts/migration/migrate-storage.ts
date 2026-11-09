import {randomUUID} from "node:crypto";
import {applicationDefault, initializeApp} from "firebase-admin/app";
import {getStorage} from "firebase-admin/storage";
import {
  SOURCE_PROJECT, parseArgs, readPrivateJson, requireApprovalForApply, stringArg, writePrivateJson,
  writeTarget,
} from "./common.js";
import {
  Decisions, Snapshot, StorageMap, StorageMapEntry, legacyTaskPhotoTarget, storagePathFromUrl,
} from "./plan.js";

// Copies legacy Storage objects into the target bucket and writes the storage
// map consumed by migrate-firestore. The source bucket is only read.
//
// - task_photos/{taskId}/… → task_evidence/{employeeId}/legacy_{taskId}/…
// - role_requests/resumes/… copied unchanged only when decisions.copyResumes.
// Idempotent: an existing target object with the same MD5 is reused (and its
// download token kept); a different object at the target path is a conflict.
//
// Usage (dry run is the default):
//   node lib/scripts/migration/migrate-storage.js --snapshot=… --decisions=… \
//     --target=dowell-pest-control-prod --map-out=/abs/storage-map.json \
//     [--apply --confirm-target=dowell-pest-control-prod]

function downloadUrl(bucket: string, path: string, token: string): string {
  return `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucket)}/o/` +
    `${encodeURIComponent(path)}?alt=media&token=${encodeURIComponent(token)}`;
}

async function main(): Promise<void> {
  const args = parseArgs();
  const {project, apply} = writeTarget(args);
  const snapshot = readPrivateJson<Snapshot>(stringArg(args, "snapshot") as string);
  const decisions = readPrivateJson<Decisions>(stringArg(args, "decisions") as string);
  const mapOut = stringArg(args, "map-out") as string;
  requireApprovalForApply(apply, decisions);

  const sourceObjects = new Map(snapshot.storage.objects.map((object) => [object.name, object]));
  const copies: {source: string; target: string; taskId?: string}[] = [];
  const problems: {code: string; path: string}[] = [];
  const map: StorageMap = {bucket: `${project}.firebasestorage.app`, taskPhotos: {}};

  for (const doc of snapshot.documents) {
    const parts = doc.path.split("/");
    // A never-provisioned source bucket has nothing to copy; the plan reports it.
    if (snapshot.storage.exists === false) break;
    if (parts[0] !== "employee_tasks" || parts.length !== 2) continue;
    const photos = Array.isArray(doc.data.photos) ? doc.data.photos : [];
    const owner = (doc.data.employeeId ?? doc.data.userId) as string | undefined;
    if (photos.length === 0) continue;
    if (!owner) {
      problems.push({code: "task-without-owner", path: doc.path});
      continue;
    }
    for (const url of photos) {
      const sourcePath = typeof url === "string" ? storagePathFromUrl(url) : undefined;
      if (!sourcePath || !sourceObjects.has(sourcePath)) {
        problems.push({code: "source-object-missing", path: doc.path});
        continue;
      }
      copies.push({source: sourcePath, target: legacyTaskPhotoTarget(owner, parts[1], sourcePath), taskId: parts[1]});
    }
  }
  if (decisions.copyResumes) {
    for (const name of sourceObjects.keys()) {
      if (name.startsWith("role_requests/resumes/")) copies.push({source: name, target: name});
    }
  }
  const referenced = new Set(copies.map((copy) => copy.source));
  const unreferenced: Record<string, number> = {};
  for (const name of sourceObjects.keys()) {
    if (referenced.has(name)) continue;
    const prefix = name.split("/")[0];
    unreferenced[prefix] = (unreferenced[prefix] ?? 0) + 1;
  }

  const app = initializeApp({credential: applicationDefault(), projectId: project}, "storage-migration");
  const sourceBucket = getStorage(app).bucket(snapshot.storage.bucket);
  if (snapshot.storage.bucket !== `${SOURCE_PROJECT}.firebasestorage.app`) {
    throw new Error("Snapshot bucket is not the legacy project bucket.");
  }
  const targetBucket = getStorage(app).bucket(map.bucket);

  const outcome = {copied: 0, reused: 0, wouldCopy: 0, conflicts: 0};
  for (const copy of copies) {
    const target = targetBucket.file(copy.target);
    const [exists] = await target.exists();
    let token: string | null = null;
    if (exists) {
      const [metadata] = await target.getMetadata();
      if (metadata.md5Hash !== sourceObjects.get(copy.source)?.md5) {
        outcome.conflicts++;
        problems.push({code: "target-object-differs", path: copy.target});
        continue;
      }
      const tokens = metadata.metadata?.firebaseStorageDownloadTokens;
      token = typeof tokens === "string" ? tokens.split(",")[0] : null;
      outcome.reused++;
    } else if (apply) {
      await sourceBucket.file(copy.source).copy(target);
      outcome.copied++;
    } else {
      outcome.wouldCopy++;
    }
    if (apply && !token) {
      token = randomUUID();
      await target.setMetadata({metadata: {firebaseStorageDownloadTokens: token, migratedFrom: copy.source}});
    }
    if (copy.taskId) {
      const entry: StorageMapEntry = {
        sourcePath: copy.source, path: copy.target,
        url: token ? downloadUrl(map.bucket, copy.target, token) : null,
      };
      (map.taskPhotos[copy.taskId] ??= []).push(entry);
    }
  }
  // Entries stay in each task's original photo order.
  writePrivateJson(mapOut, map);
  console.log(JSON.stringify({
    mode: apply ? "apply" : "dry-run", target: project, planned: copies.length, ...outcome,
    problems: problems.reduce<Record<string, number>>((acc, item) => {
      acc[item.code] = (acc[item.code] ?? 0) + 1;
      return acc;
    }, {}),
    unreferencedSourceObjectsByPrefix: unreferenced,
  }, null, 2));
  if (problems.length > 0) process.exitCode = 2;
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
