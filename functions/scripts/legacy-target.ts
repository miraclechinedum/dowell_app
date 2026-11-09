// Target guard for the legacy maintenance scripts (bootstrap-admin,
// backfill-user-profiles, backfill-referral-identities). Pure: validates the
// command line and environment before any Firebase app is initialized.
//
// - `--project=<id>` is always required and must be an approved target; the
//   legacy source project is always refused.
// - Writes need `--apply` plus `--confirm-target` exactly equal to `--project`.
//   Without `--apply` the script is a dry run and needs no confirmation.
// - Environment variables that select a project must not name a different one,
//   and the initialized app's project is re-checked before any write.

export const LEGACY_SOURCE_PROJECT = "dowell-pest-control";
export const LEGACY_SCRIPT_TARGETS = new Set(["dowell-pest-control-prod"]);
const PROJECT_ENV_VARS = ["GOOGLE_CLOUD_PROJECT", "GCLOUD_PROJECT", "GCP_PROJECT"];

export interface LegacyRun {
  project: string;
  apply: boolean;
  positionals: string[];
}

function envProjects(env: Record<string, string | undefined>): string[] {
  const found = PROJECT_ENV_VARS.map((name) => env[name]).filter((value): value is string => !!value);
  if (env.FIREBASE_CONFIG) {
    try {
      const config = JSON.parse(env.FIREBASE_CONFIG) as {projectId?: unknown};
      if (typeof config.projectId === "string") found.push(config.projectId);
    } catch {
      throw new Error("FIREBASE_CONFIG is set but is not valid JSON; refusing to guess the project.");
    }
  }
  return found;
}

export function resolveLegacyTarget(
  argv: string[], env: Record<string, string | undefined>, options: {allowPositionals?: boolean} = {},
): LegacyRun {
  let project: string | undefined;
  let confirm: string | undefined;
  let apply = false;
  const positionals: string[] = [];
  for (const raw of argv) {
    if (raw === "--apply") apply = true;
    else if (raw.startsWith("--project=")) project = raw.slice("--project=".length);
    else if (raw.startsWith("--confirm-target=")) confirm = raw.slice("--confirm-target=".length);
    else if (raw.startsWith("--")) throw new Error(`Unknown option: ${raw}`);
    else positionals.push(raw);
  }
  if (!project) throw new Error("--project=<id> is required.");
  if (project === LEGACY_SOURCE_PROJECT) {
    throw new Error(`Refusing ${LEGACY_SOURCE_PROJECT}: the legacy project must remain unchanged.`);
  }
  if (!LEGACY_SCRIPT_TARGETS.has(project)) {
    throw new Error(`Refusing unapproved project ${project}. Allowed: ${[...LEGACY_SCRIPT_TARGETS].join(", ")}.`);
  }
  const mismatched = envProjects(env).filter((value) => value !== project);
  if (mismatched.length > 0) {
    throw new Error("The environment selects a different Firebase project than --project; unset it and retry.");
  }
  if (apply && confirm !== project) throw new Error(`--apply requires --confirm-target=${project}.`);
  if (!options.allowPositionals && positionals.length > 0) {
    throw new Error(`Unexpected argument: ${positionals[0]}`);
  }
  return {project, apply, positionals};
}

/** Re-checks the initialized app's project before any read or write. */
export function assertInitializedProject(actual: string | undefined, expected: string): void {
  if (actual !== expected) {
    throw new Error("Initialized Firebase project does not match --project; refusing to continue.");
  }
}
