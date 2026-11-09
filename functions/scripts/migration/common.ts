import {createHash} from "node:crypto";
import {chmodSync, existsSync, lstatSync, mkdirSync, readFileSync, realpathSync, writeFileSync} from "node:fs";
import {homedir} from "node:os";
import {dirname, isAbsolute, join, relative, resolve} from "node:path";

// Shared guards and encoding for the one-way Firebase project migration.
// The legacy production project is read-only for every tool in this folder.

export const SOURCE_PROJECT = "dowell-pest-control";
/** The only project migration tools may write to. Staging is not used. */
export const WRITABLE_TARGETS = new Set([
  "dowell-pest-control-prod",
]);
export const SCHEMA_TAG = "dowell-migration-v1";

export type Args = Map<string, string | true>;

export function parseArgs(argv = process.argv.slice(2)): Args {
  const args: Args = new Map();
  for (const raw of argv) {
    if (!raw.startsWith("--")) throw new Error(`Unexpected argument: ${raw}`);
    const [key, ...rest] = raw.slice(2).split("=");
    args.set(key, rest.length > 0 ? rest.join("=") : true);
  }
  return args;
}

/** Private default location for snapshots and reports, outside the repository. */
export const DATA_DIR = join(homedir(), "DowellMigration");

export function pathArg(args: Args, key: string, defaultName: string): string {
  return stringArg(args, key, false) ?? join(DATA_DIR, defaultName);
}

export function stringArg(args: Args, key: string, required = true): string | undefined {
  const value = args.get(key);
  if (typeof value === "string" && value.length > 0) return value;
  if (required) throw new Error(`--${key}=<value> is required.`);
  return undefined;
}

export function repoRoot(): string {
  let current = realpathSync(__dirname);
  while (current !== dirname(current)) {
    if (existsSync(join(current, "pubspec.yaml"))) return current;
    current = dirname(current);
  }
  throw new Error("Repository root (pubspec.yaml) not found.");
}

/** Customer data and reports must never be written inside the repository. */
export function outsideRepoPath(path: string): string {
  if (!isAbsolute(path)) throw new Error(`Path must be absolute: ${path}`);
  const resolved = resolve(path);
  const fromRepo = relative(repoRoot(), resolved);
  if (fromRepo === "" || (!fromRepo.startsWith("..") && !isAbsolute(fromRepo))) {
    throw new Error("Refusing to read or write migration data inside the repository.");
  }
  return resolved;
}

export function writePrivateJson(path: string, value: unknown): void {
  const target = outsideRepoPath(path);
  const dir = dirname(target);
  mkdirSync(dir, {recursive: true, mode: 0o700});
  // Re-check after resolving symlinks, then enforce owner-only permissions even
  // when the directory or file already existed.
  outsideRepoPath(join(realpathSync(dir), "x"));
  chmodSync(dir, 0o700);
  writeFileSync(target, `${JSON.stringify(value, null, 2)}\n`, {mode: 0o600});
  chmodSync(target, 0o600);
}

export function readPrivateJson<T>(path: string): T {
  return JSON.parse(readFileSync(outsideRepoPath(path), "utf8")) as T;
}

/**
 * Validates a write target. Writes need --apply plus --confirm-target equal to
 * the target, and the legacy project can never be a target.
 */
export function writeTarget(args: Args): {project: string; apply: boolean} {
  const project = stringArg(args, "target") as string;
  if (project === SOURCE_PROJECT || !WRITABLE_TARGETS.has(project)) {
    throw new Error(`Refusing to write to ${project}. Allowed: ${[...WRITABLE_TARGETS].join(", ")}.`);
  }
  const apply = args.get("apply") === true;
  if (apply && args.get("confirm-target") !== project) {
    throw new Error(`--apply requires --confirm-target=${project}.`);
  }
  return {project, apply};
}

/**
 * Authoritative migration lock: a fixed file, independent of `--decisions`, so
 * an archived approved decisions file cannot bypass it. There is deliberately
 * no command-line override. Writes are allowed only when the file exists, is a
 * regular owner-controlled file, and records an explicit, approved unlock:
 *
 *   {"locked": false, "unlockApproval": {"reference": "...", "approvedBy": "...",
 *    "approvedOn": "YYYY-MM-DD"}}
 *
 * A missing, unreadable, malformed or permissive lock file fails closed.
 */
export const MIGRATION_LOCK_FILE = join(DATA_DIR, "migration-lock.json");

export function assertMigrationUnlocked(lockFile: string = MIGRATION_LOCK_FILE): void {
  const refuse = (why: string): never => {
    throw new Error(`Refusing to apply: ${why}. See functions/README.md (migration lock).`);
  };
  let stat;
  try {
    stat = lstatSync(lockFile);
  } catch {
    return refuse("migration lock state is missing or unreadable");
  }
  if (stat.isSymbolicLink() || !stat.isFile()) refuse("migration lock is not a regular file");
  if ((stat.mode & 0o022) !== 0) refuse("migration lock file is writable by group or others");
  let state: {locked?: unknown; unlockApproval?: Record<string, unknown>};
  try {
    state = JSON.parse(readFileSync(lockFile, "utf8"));
  } catch {
    return refuse("migration lock state is unreadable or malformed");
  }
  if (state.locked !== false) refuse("the completed migration is locked");
  const approval = state.unlockApproval;
  const filled = (value: unknown) => typeof value === "string" && value.trim().length > 0;
  if (!approval || !filled(approval.reference) || !filled(approval.approvedBy) ||
      !filled(approval.approvedOn) || Number.isNaN(Date.parse(String(approval.approvedOn)))) {
    refuse("the migration unlock has no complete written approval");
  }
}

/**
 * Gate for --apply, checked before any Firebase app is initialized: first the
 * authoritative migration lock, then the decisions file's top-level `approved`
 * (exactly true) and, for provisioning, `clientAdmin.approved`. Dry runs are
 * unaffected. `lockFile` exists only for tests; tools never pass it.
 */
export function requireApprovalForApply(
  apply: boolean,
  decisions: {approved?: unknown; clientAdmin?: {approved?: unknown}},
  options: {clientAdmin?: boolean; lockFile?: string} = {},
): void {
  if (!apply) return;
  assertMigrationUnlocked(options.lockFile ?? MIGRATION_LOCK_FILE);
  if (decisions.approved !== true) {
    throw new Error("Refusing to apply: decisions are not approved.");
  }
  if (options.clientAdmin && decisions.clientAdmin?.approved !== true) {
    throw new Error("Refusing to apply: clientAdmin is not approved.");
  }
}

// ─── Firestore value encoding ────────────────────────────────────────────────
// Snapshots store Firestore values as JSON with explicit markers so they can be
// hashed deterministically and written back with their original types.

export type Encoded =
  | null | boolean | number | string | Encoded[]
  | {[key: string]: Encoded};

export type EncodedTimestamp = {
  __type: "timestamp";
  seconds: number;
  nanoseconds: number;
};

export function isEncodedTimestamp(value: unknown): value is EncodedTimestamp {
  return typeof value === "object" && value != null &&
    (value as {__type?: unknown}).__type === "timestamp";
}

export function timestampFromIso(iso: string): EncodedTimestamp {
  const millis = Date.parse(iso);
  if (Number.isNaN(millis)) throw new Error(`Invalid ISO timestamp: ${iso}`);
  return {__type: "timestamp", seconds: Math.floor(millis / 1000), nanoseconds: (millis % 1000) * 1e6};
}

export function stableStringify(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;
  if (value != null && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([, item]) => item !== undefined)
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
    return `{${entries.map(([key, item]) => `${JSON.stringify(key)}:${stableStringify(item)}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

export function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}
