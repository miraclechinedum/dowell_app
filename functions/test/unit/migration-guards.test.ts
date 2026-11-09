import assert from "node:assert/strict";
import {chmodSync, mkdirSync, mkdtempSync, readFileSync, symlinkSync, writeFileSync} from "node:fs";
import {tmpdir} from "node:os";
import {join, resolve} from "node:path";
import {describe, it} from "node:test";
import {
  DATA_DIR, MIGRATION_LOCK_FILE, SOURCE_PROJECT, assertMigrationUnlocked, parseArgs,
  requireApprovalForApply, writeTarget,
} from "../../scripts/migration/common.js";
import {approvedAdminSet} from "../../scripts/migration/claims-policy.js";

// Pure guard tests: no Firebase Admin initialization and no network access.
const PROD = "dowell-pest-control-prod";
const args = (...items: string[]) => parseArgs(items);

// Temporary lock files only; the real ~/DowellMigration lock is never touched.
const scratch = mkdtempSync(join(tmpdir(), "dowell-lock-test-"));
let counter = 0;
function lockFile(content: unknown, mode = 0o600): string {
  const path = join(scratch, `lock-${counter++}.json`);
  writeFileSync(path, typeof content === "string" ? content : JSON.stringify(content));
  chmodSync(path, mode);
  return path;
}
const UNLOCKED = {locked: false, unlockApproval: {reference: "Written approval #1", approvedBy: "Owner", approvedOn: "2026-11-01"}};
const LOCKED = {locked: true, lockedAt: "2026-10-22"};

describe("migration write-target guard", () => {
  it("accepts only the production destination, as a dry run unless --apply is given", () => {
    assert.deepEqual(writeTarget(args(`--target=${PROD}`)), {project: PROD, apply: false});
    assert.deepEqual(writeTarget(args(`--target=${PROD}`, "--apply", `--confirm-target=${PROD}`)),
      {project: PROD, apply: true});
  });

  it("rejects the legacy source project even with --apply and a matching confirmation", () => {
    assert.equal(SOURCE_PROJECT, "dowell-pest-control");
    for (const extra of [[], ["--apply", `--confirm-target=${SOURCE_PROJECT}`]]) {
      assert.throws(() => writeTarget(args(`--target=${SOURCE_PROJECT}`, ...extra)), /Refusing to write/);
    }
  });

  it("rejects the retired staging project and unknown projects", () => {
    for (const project of ["dowell-pest-control-staging", "some-other-project", "DOWELL-PEST-CONTROL-PROD"]) {
      assert.throws(() => writeTarget(args(`--target=${project}`, "--apply", `--confirm-target=${project}`)),
        /Refusing to write/);
    }
  });

  it("requires a target", () => {
    assert.throws(() => writeTarget(args("--apply")), /--target/);
  });

  it("treats a missing or non-flag --apply as a dry run", () => {
    assert.equal(writeTarget(args(`--target=${PROD}`, `--confirm-target=${PROD}`)).apply, false);
    assert.equal(writeTarget(args(`--target=${PROD}`, "--apply=true", `--confirm-target=${PROD}`)).apply, false);
  });

  it("rejects --apply without an exact --confirm-target", () => {
    for (const confirm of [[], [`--confirm-target=${SOURCE_PROJECT}`], ["--confirm-target=dowell-pest-control-staging"],
      [`--confirm-target=${PROD} `], ["--confirm-target"]]) {
      assert.throws(() => writeTarget(args(`--target=${PROD}`, "--apply", ...confirm)), /--confirm-target/);
    }
  });
});

describe("migration approval gate", () => {
  const locked = {approved: false, clientAdmin: {approved: true}};

  it("never blocks a dry run", () => {
    assert.doesNotThrow(() => requireApprovalForApply(false, {}));
    assert.doesNotThrow(() => requireApprovalForApply(false, locked, {clientAdmin: true}));
  });

  it("rejects --apply when top-level approval is missing, false, or not exactly true", () => {
    const open = lockFile(UNLOCKED);
    for (const decisions of [{}, {approved: false}, {approved: "true"}, {approved: 1}, locked]) {
      assert.throws(() => requireApprovalForApply(true, decisions, {lockFile: open}), /decisions are not approved/);
      assert.throws(() => requireApprovalForApply(true, decisions, {clientAdmin: true, lockFile: open}),
        /decisions are not approved/);
    }
    assert.doesNotThrow(() => requireApprovalForApply(true, {approved: true}, {lockFile: open}));
  });

  it("requires client-admin approval separately, only for provisioning", () => {
    const open = lockFile(UNLOCKED);
    const generalOnly = {approved: true, clientAdmin: {approved: false}};
    assert.doesNotThrow(() => requireApprovalForApply(true, generalOnly, {lockFile: open}));
    assert.throws(() => requireApprovalForApply(true, generalOnly, {clientAdmin: true, lockFile: open}),
      /clientAdmin is not approved/);
    assert.throws(() => requireApprovalForApply(true, {approved: true}, {clientAdmin: true, lockFile: open}),
      /clientAdmin is not approved/);
    assert.doesNotThrow(() => requireApprovalForApply(true, {approved: true, clientAdmin: {approved: true}},
      {clientAdmin: true, lockFile: open}));
  });

  it("leaves validation's view of the approved client admin unchanged when the migration is locked", () => {
    const clientAdmin = {email: "client@example.test", approved: true};
    const profiles = [{id: "client", email: "client@example.test", provisionedClientAdmin: true}];
    const open = approvedAdminSet({approvedAdminUids: [], clientAdmin}, profiles);
    const lockedSet = approvedAdminSet({...locked, approvedAdminUids: [], clientAdmin}, profiles);
    assert.deepEqual([...lockedSet], [...open]);
    assert.deepEqual([...lockedSet], ["client"]);
  });
});


describe("authoritative migration lock", () => {
  // An archived, fully approved decisions file (as kept in ~/DowellMigration).
  const approvedArchive = {approved: true, clientAdmin: {approved: true}};

  it("lives at a fixed path in the private data directory, not next to --decisions", () => {
    assert.equal(MIGRATION_LOCK_FILE, join(DATA_DIR, "migration-lock.json"));
  });

  it("refuses --apply with an approved archive when the migration is locked", () => {
    const locked = lockFile(LOCKED);
    assert.throws(() => requireApprovalForApply(true, approvedArchive, {lockFile: locked}), /migration is locked/);
    assert.throws(() => requireApprovalForApply(true, approvedArchive, {clientAdmin: true, lockFile: locked}),
      /migration is locked/);
  });

  it("checks the lock before the decisions flags", () => {
    assert.throws(() => requireApprovalForApply(true, {approved: false}, {lockFile: lockFile(LOCKED)}),
      /migration is locked/);
  });

  it("fails closed when the lock state is missing, unreadable, malformed or permissive", () => {
    const missing = join(scratch, "does-not-exist.json");
    const directory = join(scratch, "a-directory");
    mkdirSync(directory);
    const target = lockFile(UNLOCKED);
    const link = join(scratch, "link.json");
    symlinkSync(target, link);
    const unreadable = lockFile(UNLOCKED, 0o000);
    const cases: [string, RegExp][] = [
      [missing, /missing or unreadable/],
      [directory, /not a regular file/],
      [link, /not a regular file/],
      [lockFile("{not json"), /malformed/],
      [lockFile(UNLOCKED, 0o620), /writable by group or others/],
      [lockFile(UNLOCKED, 0o602), /writable by group or others/],
      [lockFile({}), /migration is locked/],
      [lockFile({locked: "false"}), /migration is locked/],
    ];
    // Reading a mode-000 file fails for a normal user; root can still read it.
    if (process.getuid?.() !== 0) cases.push([unreadable, /malformed|unreadable/]);
    for (const [path, message] of cases) {
      assert.throws(() => requireApprovalForApply(true, approvedArchive, {lockFile: path}), message, path);
    }
  });

  it("requires a complete written approval to unlock", () => {
    for (const unlockApproval of [undefined, {}, {reference: "x", approvedBy: "y"},
      {reference: " ", approvedBy: "y", approvedOn: "2026-11-01"}, {reference: "x", approvedBy: "y", approvedOn: "soon"}]) {
      assert.throws(() => assertMigrationUnlocked(lockFile({locked: false, unlockApproval})), /written approval/);
    }
    assert.doesNotThrow(() => assertMigrationUnlocked(lockFile(UNLOCKED)));
  });

  it("never affects dry runs or read-only use", () => {
    for (const path of [join(scratch, "nothing-here.json"), lockFile(LOCKED), lockFile("{bad")]) {
      assert.doesNotThrow(() => requireApprovalForApply(false, approvedArchive, {lockFile: path}));
      assert.doesNotThrow(() => requireApprovalForApply(false, {approved: false}, {clientAdmin: true, lockFile: path}));
    }
  });
});

describe("write-capable migration scripts check target and approval before Firebase", () => {
  const dir = resolve(__dirname, "../../../scripts/migration");
  const scripts: Record<string, {clientAdmin: boolean}> = {
    "apply-claims.ts": {clientAdmin: false},
    "import-auth-users.ts": {clientAdmin: false},
    "migrate-firestore.ts": {clientAdmin: false},
    "migrate-storage.ts": {clientAdmin: false},
    "provision-client-admin.ts": {clientAdmin: true},
  };

  for (const [file, expected] of Object.entries(scripts)) {
    it(file, () => {
      const source = readFileSync(resolve(dir, file), "utf8");
      const target = source.indexOf("writeTarget(args)");
      const approval = source.indexOf("requireApprovalForApply(apply, decisions");
      const firebase = source.indexOf("initializeApp(");
      assert.ok(target > 0 && approval > target && firebase > approval,
        "writeTarget, then the approval gate, must both run before initializeApp");
      assert.equal(source.includes("requireApprovalForApply(apply, decisions, {clientAdmin: true})"), expected.clientAdmin);
      assert.ok(!source.includes("lockFile"), "tools must use the fixed lock path, never their own");
      assert.ok(!/migration-lock/.test(source), "no tool may reference or redirect the lock file");
    });
  }
});
