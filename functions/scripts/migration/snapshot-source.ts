import {applicationDefault, initializeApp} from "firebase-admin/app";
import {CollectionReference, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {SOURCE_PROJECT, parseArgs, pathArg, sha256, stableStringify, writePrivateJson} from "./common.js";
import {encodeValue} from "./firestore-codec.js";
import {Snapshot, SnapshotDoc} from "./plan.js";

// READ-ONLY. Captures the legacy project's Firestore documents (all collections
// and subcollections, read in one read-only transaction) and its Storage object
// listing (names, sizes, hashes; no file contents) into a private JSON file
// outside the repository. It issues no writes of any kind.
//
// Usage:
//   node lib/scripts/migration/snapshot-source.js [--out=/abs/path/source-snapshot.json]
// The default output is ~/DowellMigration/source-snapshot.json.

async function main(): Promise<void> {
  const args = parseArgs();
  const out = pathArg(args, "out", "source-snapshot.json");
  const app = initializeApp({credential: applicationDefault(), projectId: SOURCE_PROJECT}, "source-readonly");
  const db = getFirestore(app);

  const rootCollections = await db.listCollections();

  const takenAt = new Date().toISOString();
  const documents: SnapshotDoc[] = await db.runTransaction(async (transaction) => {
    // Rebuilt on every attempt so a retried transaction cannot duplicate reads.
    const collections: CollectionReference[] = [...rootCollections];
    const found: SnapshotDoc[] = [];
    for (let index = 0; index < collections.length; index++) {
      const snapshot = await transaction.get(collections[index]);
      for (const doc of snapshot.docs) {
        found.push({path: doc.ref.path, data: encodeValue(doc.data()) as SnapshotDoc["data"]});
        // Subcollections are discovered per document and read in the same pass.
        collections.push(...await doc.ref.listCollections());
      }
    }
    return found;
  }, {readOnly: true});
  documents.sort((a, b) => (a.path < b.path ? -1 : 1));

  // The legacy app was configured for this bucket, but on the Spark plan it was
  // never provisioned. A missing bucket (404) is recorded, not treated as fatal.
  const bucketName = `${SOURCE_PROJECT}.firebasestorage.app`;
  let bucketExists = true;
  const files = await getStorage(app).bucket(bucketName).getFiles()
    .then(([found]) => found)
    .catch((error: unknown) => {
      if ((error as {code?: unknown}).code !== 404) throw error;
      bucketExists = false;
      return [];
    });
  const objects = files.map((file) => ({
    name: file.name,
    size: Number(file.metadata.size ?? 0),
    md5: typeof file.metadata.md5Hash === "string" ? file.metadata.md5Hash : null,
    contentType: typeof file.metadata.contentType === "string" ? file.metadata.contentType : null,
  })).sort((a, b) => (a.name < b.name ? -1 : 1));

  const snapshotId = sha256(stableStringify({documents, objects}));
  const snapshot: Snapshot = {
    formatVersion: 1, sourceProject: SOURCE_PROJECT, takenAt, snapshotId,
    documents, storage: {bucket: bucketName, exists: bucketExists, objects},
  };
  writePrivateJson(out, snapshot);

  const counts: Record<string, number> = {};
  for (const doc of documents) {
    const key = doc.path.split("/").filter((_, i) => i % 2 === 0).join("/*/");
    counts[key] = (counts[key] ?? 0) + 1;
  }
  // Aggregates only; the file itself contains customer data and stays private.
  console.log(JSON.stringify({snapshotId, takenAt, documentCounts: counts, storageBucketExists: bucketExists, storageObjects: objects.length}, null, 2));
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
