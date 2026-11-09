// Guard for verify-storage-token-revocation.ts, which REMOVES the download
// token of a Storage object. Pure: validates arguments before Firebase Admin is
// initialized or any Storage call is made.
//
// The allowlist lives in source code and cannot be supplied on the command line.
// Approving a bucket requires a reviewed code change that adds an entry naming
// the exact bucket and operation with a written approval reference. The legacy
// and production default buckets additionally need an explicit
// protectedBucketApprovalReference.

export const PROBE_OPERATION = "revoke-download-token";

export interface ApprovedProbeBucket {
  bucket: string;
  operation: typeof PROBE_OPERATION;
  approvalReference: string;
  approvedOn: string;
  /** Required only for the legacy or production default buckets. */
  protectedBucketApprovalReference?: string;
}

/** No bucket is approved: the probe is disabled until a reviewed change adds one. */
export const APPROVED_PROBE_BUCKETS: readonly ApprovedProbeBucket[] = Object.freeze([]);

export const PROTECTED_BUCKETS: ReadonlySet<string> = new Set([
  "dowell-pest-control.firebasestorage.app",
  "dowell-pest-control.appspot.com",
  "dowell-pest-control-prod.firebasestorage.app",
  "dowell-pest-control-prod.appspot.com",
]);

export interface ProbeRequest {
  bucket: string;
  object: string;
  oldUrl?: string;
}

const VALUE_OPTIONS = new Set(["bucket", "object", "old-url", "confirm-bucket"]);

function parse(argv: string[]): Map<string, string> {
  const values = new Map<string, string>();
  for (let index = 0; index < argv.length; index++) {
    const raw = argv[index];
    if (raw === "--confirm-staging") {
      throw new Error("--confirm-staging is no longer accepted: it does not identify an approved bucket. " +
        "Use --confirm-bucket=<bucket> with a bucket approved in storage-probe-guard.ts.");
    }
    if (!raw.startsWith("--")) throw new Error(`Unexpected argument: ${raw}`);
    const [name, ...rest] = raw.slice(2).split("=");
    if (!VALUE_OPTIONS.has(name)) throw new Error(`Unknown option: --${name}`);
    if (values.has(name)) throw new Error(`Duplicate option: --${name}`);
    // Accept both --name=value and the script's original --name value form.
    const value = rest.length > 0 ? rest.join("=") : argv[++index];
    if (value === undefined || value.length === 0 || value.startsWith("--")) {
      throw new Error(`--${name} requires a value.`);
    }
    values.set(name, value);
  }
  return values;
}

/**
 * Validates the probe request. `allowlist` exists only so tests can inject
 * approvals; the script always uses the built-in APPROVED_PROBE_BUCKETS.
 */
export function validateProbeArgs(
  argv: string[], allowlist: readonly ApprovedProbeBucket[] = APPROVED_PROBE_BUCKETS,
): ProbeRequest {
  const values = parse(argv);
  const bucket = values.get("bucket");
  const object = values.get("object");
  if (!bucket || !object) {
    throw new Error("Usage: --bucket=<bucket> --object=<path> --confirm-bucket=<bucket> [--old-url=<url>]");
  }
  if (allowlist.length === 0) {
    throw new Error("No Storage bucket is approved for the token-revocation probe; it is disabled.");
  }
  const entry = allowlist.find((item) => item.bucket === bucket);
  if (!entry) throw new Error(`Bucket ${bucket} is not approved for this probe.`);
  const filled = (value: unknown) => typeof value === "string" && value.trim().length > 0;
  if (entry.operation !== PROBE_OPERATION || !filled(entry.approvalReference) ||
      !filled(entry.approvedOn) || Number.isNaN(Date.parse(entry.approvedOn))) {
    throw new Error(`Approval for bucket ${bucket} is incomplete or for a different operation.`);
  }
  if (PROTECTED_BUCKETS.has(bucket) && !filled(entry.protectedBucketApprovalReference)) {
    throw new Error(`Bucket ${bucket} is a Dowell project bucket and needs a separate written approval.`);
  }
  if (values.get("confirm-bucket") !== bucket) {
    throw new Error(`Confirm the exact bucket with --confirm-bucket=${bucket}.`);
  }
  return {bucket, object, ...(values.has("old-url") ? {oldUrl: values.get("old-url")} : {})};
}

// ─── Logging without credentials ─────────────────────────────────────────────
// Download tokens and token-bearing URLs grant read access to the object, so the
// probe never logs them: only identifiers, token presence and the outcome.

export interface ProbeReport {
  bucket: string;
  object: string;
  tokenPresentBefore: boolean;
  tokenPresentAfter: boolean;
  oldUrlHttpStatus: number;
  result: "PASS" | "FAIL";
}

export function probeReport(input: {
  bucket: string; object: string; tokenBefore: unknown; tokenAfter: unknown; status: number;
}): ProbeReport {
  const present = (value: unknown) => typeof value === "string" && value.length > 0;
  // Outcome rule unchanged from the original probe: the old URL must be refused.
  const revoked = input.status === 401 || input.status === 403 || input.status === 404;
  return {
    bucket: input.bucket,
    object: input.object,
    tokenPresentBefore: present(input.tokenBefore),
    tokenPresentAfter: present(input.tokenAfter),
    oldUrlHttpStatus: input.status,
    result: revoked ? "PASS" : "FAIL",
  };
}

/** Removes token query parameters and token-like values from error text. */
export function redactCredentials(text: string): string {
  return text
    .replace(/([?&](?:token|access_token|X-Goog-Signature|sig)=)[^&\s"']+/gi, "$1[redacted]")
    .replace(/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi, "[redacted-token]")
    .replace(/\bya29\.[A-Za-z0-9._-]+/g, "[redacted-access-token]");
}
