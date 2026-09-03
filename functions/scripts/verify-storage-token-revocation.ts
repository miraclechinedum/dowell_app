import {applicationDefault, initializeApp} from "firebase-admin/app";
import {getStorage} from "firebase-admin/storage";

function argument(name: string): string | undefined {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

async function main() {
  const bucketName = argument("bucket");
  const objectPath = argument("object");
  const suppliedUrl = argument("old-url");
  if (!bucketName || !objectPath) {
    throw new Error("Usage: --bucket BUCKET --object PATH [--old-url URL] --confirm-staging");
  }
  if (!process.argv.includes("--confirm-staging")) {
    throw new Error("Refusing to mutate metadata without --confirm-staging.");
  }

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
  const passed = response.status === 401 || response.status === 403 || response.status === 404;
  console.log({
    bucket: bucketName,
    object: objectPath,
    oldToken,
    tokenMetadataAfter: after.metadata?.firebaseStorageDownloadTokens ?? null,
    oldUrlHttpStatus: response.status,
    result: passed ? "PASS" : "FAIL",
  });
  if (!passed) process.exitCode = 1;
}

main().catch((error) => {
  console.error("Staging token-revocation probe failed", error);
  process.exitCode = 1;
});
