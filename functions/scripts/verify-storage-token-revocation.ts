import {applicationDefault, initializeApp} from "firebase-admin/app";
import {getStorage} from "firebase-admin/storage";
import {probeReport, redactCredentials, validateProbeArgs} from "./storage-probe-guard.js";

// Removes the download token of one Storage object and checks that a captured
// URL stops working. Only buckets approved in storage-probe-guard.ts (currently
// none) can be used; arguments are validated before Firebase is initialized.
async function main() {
  const {bucket: bucketName, object: objectPath, oldUrl: suppliedUrl} =
    validateProbeArgs(process.argv.slice(2));

  initializeApp({credential: applicationDefault(), storageBucket: bucketName});
  const file = getStorage().bucket(bucketName).file(objectPath);
  const [before] = await file.getMetadata();
  const rawToken = before.metadata?.firebaseStorageDownloadTokens;
  const oldToken = typeof rawToken === "string" ? rawToken : undefined;
  if (!oldToken && !suppliedUrl) {
    throw new Error("Object has no existing token; supply --old-url if testing a captured URL.");
  }
  const token = oldToken?.split(",")[0];
  const oldUrl = suppliedUrl ??
    `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucketName)}` +
    `/o/${encodeURIComponent(objectPath)}?alt=media&token=${encodeURIComponent(token ?? "")}`;

  await file.setMetadata({metadata: {firebaseStorageDownloadTokens: null}});
  const [after] = await file.getMetadata();
  const response = await fetch(oldUrl, {redirect: "manual"});
  // Never log tokens or the token-bearing URL: identifiers, presence and outcome only.
  const report = probeReport({
    bucket: bucketName, object: objectPath, tokenBefore: oldToken,
    tokenAfter: after.metadata?.firebaseStorageDownloadTokens, status: response.status,
  });
  console.log(report);
  if (report.result !== "PASS") process.exitCode = 1;
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error("Storage token-revocation probe failed:", redactCredentials(message));
  process.exitCode = 1;
});
