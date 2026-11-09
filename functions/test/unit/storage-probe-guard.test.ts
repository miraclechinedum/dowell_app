import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {describe, it} from "node:test";
import {
  APPROVED_PROBE_BUCKETS, ApprovedProbeBucket, PROBE_OPERATION, PROTECTED_BUCKETS, probeReport, redactCredentials,
  validateProbeArgs,
} from "../../scripts/storage-probe-guard.js";

// Pure tests: no Firebase initialization, no Storage access.
const TEST_BUCKET = "throwaway-probe-bucket";
const approved: ApprovedProbeBucket = {
  bucket: TEST_BUCKET, operation: PROBE_OPERATION, approvalReference: "Written approval #42", approvedOn: "2026-11-01",
};
const valid = (bucket = TEST_BUCKET) => [`--bucket=${bucket}`, "--object=task_evidence/u/r/photo_0.jpg", `--confirm-bucket=${bucket}`];

describe("storage token probe guard", () => {
  it("ships with an empty, frozen allowlist, so every request is refused", () => {
    assert.equal(APPROVED_PROBE_BUCKETS.length, 0);
    assert.ok(Object.isFrozen(APPROVED_PROBE_BUCKETS));
    for (const bucket of [TEST_BUCKET, ...PROTECTED_BUCKETS]) {
      assert.throws(() => validateProbeArgs(valid(bucket)), /disabled/);
    }
  });

  it("rejects missing bucket or object before anything else", () => {
    for (const argv of [[], ["--object=x", `--confirm-bucket=${TEST_BUCKET}`], [`--bucket=${TEST_BUCKET}`]]) {
      assert.throws(() => validateProbeArgs(argv, [approved]), /Usage:/);
    }
  });

  it("no longer accepts --confirm-staging, even for an approved bucket", () => {
    assert.throws(() => validateProbeArgs([...valid(), "--confirm-staging"], [approved]), /--confirm-staging is no longer accepted/);
    assert.throws(() => validateProbeArgs(["--bucket", TEST_BUCKET, "--object", "x", "--confirm-staging"], [approved]),
      /--confirm-staging is no longer accepted/);
  });

  it("rejects unknown options, stray arguments, duplicates and missing values", () => {
    assert.throws(() => validateProbeArgs([...valid(), "--force"], [approved]), /Unknown option: --force/);
    assert.throws(() => validateProbeArgs([...valid(), "--allowlist=evil"], [approved]), /Unknown option: --allowlist/);
    assert.throws(() => validateProbeArgs([...valid(), "stray"], [approved]), /Unexpected argument/);
    assert.throws(() => validateProbeArgs([...valid(), "--bucket=other"], [approved]), /Duplicate option/);
    assert.throws(() => validateProbeArgs(["--bucket", "--object=x"], [approved]), /requires a value/);
  });

  it("accepts an approved bucket only with the exact confirmation", () => {
    assert.deepEqual(validateProbeArgs(valid(), [approved]), {bucket: TEST_BUCKET, object: "task_evidence/u/r/photo_0.jpg"});
    assert.deepEqual(
      validateProbeArgs(["--bucket", TEST_BUCKET, "--object", "o", "--confirm-bucket", TEST_BUCKET, "--old-url", "https://x"], [approved]),
      {bucket: TEST_BUCKET, object: "o", oldUrl: "https://x"});
    for (const confirm of [[], [`--confirm-bucket=${TEST_BUCKET}-other`], [`--confirm-bucket=${TEST_BUCKET.toUpperCase()}`]]) {
      assert.throws(() => validateProbeArgs([`--bucket=${TEST_BUCKET}`, "--object=o", ...confirm], [approved]),
        /--confirm-bucket=/);
    }
  });

  it("refuses buckets that are not on the allowlist or whose approval is incomplete", () => {
    assert.throws(() => validateProbeArgs(valid("unlisted-bucket"), [approved]), /not approved/);
    for (const broken of [{approvalReference: " "}, {approvedOn: "soon"}, {operation: "delete-object"}]) {
      const entry = {...approved, ...broken} as ApprovedProbeBucket;
      assert.throws(() => validateProbeArgs(valid(), [entry]), /incomplete or for a different operation/);
    }
  });

  it("refuses the legacy and production buckets without a separate written approval", () => {
    assert.ok(PROTECTED_BUCKETS.has("dowell-pest-control.firebasestorage.app"));
    assert.ok(PROTECTED_BUCKETS.has("dowell-pest-control-prod.firebasestorage.app"));
    for (const bucket of PROTECTED_BUCKETS) {
      const listed = {...approved, bucket};
      assert.throws(() => validateProbeArgs(valid(bucket), [listed]), /needs a separate written approval/);
      assert.doesNotThrow(() => validateProbeArgs(valid(bucket), [{...listed, protectedBucketApprovalReference: "Approval #7"}]));
    }
  });
});

describe("verify-storage-token-revocation validates before initializing Firebase", () => {
  it("passes only the command line to the guard, before initializeApp", () => {
    const source = readFileSync(resolve(__dirname, "../../../scripts/verify-storage-token-revocation.ts"), "utf8");
    assert.ok(!/^initializeApp\(/m.test(source), "no import-time initializeApp");
    const guard = source.indexOf("validateProbeArgs(process.argv.slice(2))");
    const init = source.indexOf("initializeApp(");
    const storage = source.indexOf("getStorage()");
    assert.ok(guard > 0 && init > guard && storage > init, "guard, then initializeApp, then Storage");
    assert.equal(source.match(/validateProbeArgs\(/g)?.length, 1);
    assert.ok(!source.includes("APPROVED_PROBE_BUCKETS") && !source.includes("confirm-staging"),
      "the script cannot supply its own allowlist or honour --confirm-staging");
  });
});

describe("storage token probe logging", () => {
  const TOKEN = "3f1c2b4a-9d8e-4f7a-b6c5-1a2b3c4d5e6f";
  const URL = `https://firebasestorage.googleapis.com/v0/b/b/o/p?alt=media&token=${TOKEN}`;

  it("reports identifiers, token presence and the outcome, never token values", () => {
    const report = probeReport({bucket: "b", object: "o/p.jpg", tokenBefore: TOKEN, tokenAfter: `${TOKEN},second`, status: 403});
    assert.deepEqual(Object.keys(report).sort(),
      ["bucket", "object", "oldUrlHttpStatus", "result", "tokenPresentAfter", "tokenPresentBefore"]);
    assert.deepEqual(report, {bucket: "b", object: "o/p.jpg", tokenPresentBefore: true, tokenPresentAfter: true,
      oldUrlHttpStatus: 403, result: "PASS"});
    const text = JSON.stringify(report);
    assert.ok(!text.includes(TOKEN) && !text.includes("second") && !text.includes("token="));
  });

  it("keeps the original outcome rule: the old URL must be refused", () => {
    for (const status of [401, 403, 404]) {
      assert.equal(probeReport({bucket: "b", object: "o", tokenBefore: TOKEN, tokenAfter: null, status}).result, "PASS");
    }
    for (const status of [200, 302, 500]) {
      assert.equal(probeReport({bucket: "b", object: "o", tokenBefore: TOKEN, tokenAfter: null, status}).result, "FAIL");
    }
    assert.equal(probeReport({bucket: "b", object: "o", tokenBefore: undefined, tokenAfter: null, status: 404}).tokenPresentBefore, false);
  });

  it("redacts token parameters and token-like values from error text", () => {
    const message = `fetch to ${URL} failed; token ${TOKEN}; auth ya29.a0AfH6SMBexample`;
    const clean = redactCredentials(message);
    assert.ok(!clean.includes(TOKEN) && !clean.includes("ya29.a0AfH6"));
    assert.match(clean, /token=\[redacted\]/);
    assert.equal(redactCredentials("Object has no existing token; supply --old-url"), "Object has no existing token; supply --old-url");
  });

  it("logs only the report and redacted errors in the script", () => {
    const source = readFileSync(resolve(__dirname, "../../../scripts/verify-storage-token-revocation.ts"), "utf8");
    const logs = source.match(/console\.(log|error|info|warn)\([^;]*\);/g) ?? [];
    assert.deepEqual(logs, [
      "console.log(report);",
      "console.error(\"Storage token-revocation probe failed:\", redactCredentials(message));",
    ]);
    // The old token reaches the report only as an input to a presence check.
    assert.equal(source.match(/\boldToken\b/g)?.length, 4, "declared, checked, split for the URL, passed to probeReport");
    assert.ok(source.includes("tokenBefore: oldToken"));
  });
});
