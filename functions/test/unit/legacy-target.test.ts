import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {describe, it} from "node:test";
import {
  LEGACY_SOURCE_PROJECT, assertInitializedProject, resolveLegacyTarget,
} from "../../scripts/legacy-target.js";

// Pure tests: no Firebase initialization and no network access.
const PROD = "dowell-pest-control-prod";
const clean: Record<string, string | undefined> = {};

describe("legacy maintenance script target guard", () => {
  it("requires an explicit --project, even for dry runs", () => {
    assert.throws(() => resolveLegacyTarget([], clean), /--project=<id> is required/);
    assert.throws(() => resolveLegacyTarget(["--apply"], clean), /--project=<id> is required/);
    assert.throws(() => resolveLegacyTarget([], {GOOGLE_CLOUD_PROJECT: PROD}), /--project=<id> is required/);
  });

  it("always refuses the legacy project, with or without confirmation", () => {
    assert.equal(LEGACY_SOURCE_PROJECT, "dowell-pest-control");
    for (const extra of [[], ["--apply", `--confirm-target=${LEGACY_SOURCE_PROJECT}`]]) {
      assert.throws(() => resolveLegacyTarget([`--project=${LEGACY_SOURCE_PROJECT}`, ...extra], clean),
        /legacy project must remain unchanged/);
    }
  });

  it("refuses unknown and retired projects", () => {
    for (const project of ["dowell-pest-control-staging", "another-project", "Dowell-Pest-Control-Prod", ""]) {
      assert.throws(() => resolveLegacyTarget([`--project=${project}`], clean), /unapproved project|--project=<id> is required/);
    }
  });

  it("requires an exact --confirm-target for --apply", () => {
    for (const confirm of [[], [`--confirm-target=${LEGACY_SOURCE_PROJECT}`], [`--confirm-target=${PROD} `], ["--confirm-target="]]) {
      assert.throws(() => resolveLegacyTarget([`--project=${PROD}`, "--apply", ...confirm], clean), /--confirm-target/);
    }
  });

  it("allows a dry run of an approved target without confirmation", () => {
    assert.deepEqual(resolveLegacyTarget([`--project=${PROD}`], clean), {project: PROD, apply: false, positionals: []});
  });

  it("accepts an explicitly approved, confirmed write target", () => {
    assert.deepEqual(resolveLegacyTarget([`--project=${PROD}`, "--apply", `--confirm-target=${PROD}`], clean),
      {project: PROD, apply: true, positionals: []});
    assert.deepEqual(resolveLegacyTarget([`--project=${PROD}`, "UID_A", "UID_B"], clean, {allowPositionals: true}),
      {project: PROD, apply: false, positionals: ["UID_A", "UID_B"]});
  });

  it("refuses when the environment selects a different project", () => {
    for (const env of [{GOOGLE_CLOUD_PROJECT: LEGACY_SOURCE_PROJECT}, {GCLOUD_PROJECT: "other"}, {GCP_PROJECT: "other"},
      {FIREBASE_CONFIG: JSON.stringify({projectId: LEGACY_SOURCE_PROJECT})}]) {
      assert.throws(() => resolveLegacyTarget([`--project=${PROD}`, "--apply", `--confirm-target=${PROD}`], env),
        /environment selects a different Firebase project/);
    }
    assert.throws(() => resolveLegacyTarget([`--project=${PROD}`], {FIREBASE_CONFIG: "{bad"}), /FIREBASE_CONFIG/);
    assert.doesNotThrow(() => resolveLegacyTarget([`--project=${PROD}`], {GOOGLE_CLOUD_PROJECT: PROD}));
  });

  it("rejects unknown options and unexpected positional arguments", () => {
    assert.throws(() => resolveLegacyTarget([`--project=${PROD}`, "--force"], clean), /Unknown option/);
    assert.throws(() => resolveLegacyTarget([`--project=${PROD}`, "stray"], clean), /Unexpected argument/);
  });

  it("re-checks the initialized project", () => {
    assert.doesNotThrow(() => assertInitializedProject(PROD, PROD));
    for (const actual of [undefined, LEGACY_SOURCE_PROJECT, "other"]) {
      assert.throws(() => assertInitializedProject(actual, PROD), /does not match/);
    }
  });
});

describe("legacy writers validate before initializing Firebase", () => {
  const dir = resolve(__dirname, "../../../scripts");
  for (const file of ["bootstrap-admin.ts", "backfill-user-profiles.ts", "backfill-referral-identities.ts"]) {
    it(file, () => {
      const source = readFileSync(resolve(dir, file), "utf8");
      assert.ok(!/^initializeApp\(/m.test(source), "no import-time initializeApp");
      const guard = source.indexOf("resolveLegacyTarget(process.argv.slice(2), process.env");
      const init = source.indexOf("initializeApp({credential: applicationDefault(), projectId: run.project})");
      const check = source.indexOf("assertInitializedProject(app.options.projectId, run.project)");
      const firstUse = Math.min(...["getFirestore()", "getAuth()"].map((call) => source.indexOf(call)).filter((i) => i >= 0));
      assert.ok(guard > 0 && init > guard && check > init && firstUse > check,
        "guard, then explicit-project init, then project check, then first Firebase use");
      assert.ok(!source.includes("process.argv.includes(\"--apply\")"), "apply comes only from the guard");
    });
  }
});
