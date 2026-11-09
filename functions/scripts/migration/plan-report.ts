import {existsSync} from "node:fs";
import {parseArgs, pathArg, readPrivateJson, sha256, stringArg, writePrivateJson} from "./common.js";
import {Decisions, Snapshot, StorageMap, buildPlan, issueCounts} from "./plan.js";

// OFFLINE. Builds the migration plan from a snapshot and prints the
// reconciliation summary (aggregates only). No Firebase access.
//
// Defaults (all under ~/DowellMigration): source-snapshot.json, decisions.json,
// plan-report.json. Without a decisions file, an unapproved draft is used and
// saved there for review, so the first report shows what must be decided.
//
// Usage:
//   node lib/scripts/migration/plan-report.js [--snapshot=…] [--decisions=…] \
//     [--storage-map=…] [--out=…]

const DRAFT_DECISIONS: Decisions = {
  approved: false,
  cutoverAt: "2026-11-01T00:00:00Z",
  balanceMapping: {
    customer: {bugBucks: "walletBalance", cashBonusBalance: "zero"},
    employee: {bugBucks: "zero", cashBonusBalance: "walletBalance"},
  },
  ledgerMismatchPolicy: "block",
  pendingPayoutPolicy: "block",
  copyResumes: false,
  approvedAdminUids: [],
};

function main(): void {
  const args = parseArgs();
  const snapshot = readPrivateJson<Snapshot>(pathArg(args, "snapshot", "source-snapshot.json"));
  const decisionsPath = pathArg(args, "decisions", "decisions.json");
  if (!existsSync(decisionsPath)) writePrivateJson(decisionsPath, DRAFT_DECISIONS);
  const decisions = readPrivateJson<Decisions>(decisionsPath);
  const mapPath = stringArg(args, "storage-map", false);
  const storageMap = mapPath ? readPrivateJson<StorageMap>(mapPath) : undefined;
  const plan = buildPlan(snapshot, decisions, storageMap);
  const outPath = pathArg(args, "out", "plan-report.json");

  // Account UIDs in paths are replaced by short hashes so the report holds no
  // personal identifiers; document data is never included.
  const uids = new Set([
    ...snapshot.documents.filter((doc) => /^users\/[^/]+$/.test(doc.path)).map((doc) => doc.path.split("/")[1]),
    ...(decisions.closedAccounts ?? []).map((account) => account.uid),
    ...(decisions.excludedAccounts ?? []).map((account) => account.uid),
    ...decisions.approvedAdminUids,
  ]);
  // UIDs can be a whole segment (users/{uid}) or embedded (migration_opening_{uid}).
  const redact = (path?: string) => {
    let out = path;
    for (const uid of uids) if (out?.includes(uid)) out = out.split(uid).join(`uid#${sha256(uid).slice(0, 10)}`);
    return out;
  };
  writePrivateJson(outPath, {
    snapshotId: plan.snapshotId,
    decisionsApproved: decisions.approved,
    summary: plan.summary,
    issues: plan.issues.map((item) => ({...item, path: redact(item.path)})),
    writes: plan.writes.map((write) => ({path: redact(write.path), origin: write.origin, contentHash: write.contentHash})),
  });
  const blockers = plan.issues.filter((item) => item.severity === "blocker").length;
  console.log(JSON.stringify({
    snapshotId: plan.snapshotId,
    decisionsApproved: decisions.approved,
    plannedWrites: plan.writes.length,
    blockers,
    issueCounts: issueCounts(plan.issues),
    summary: plan.summary,
    privateFiles: {decisions: decisionsPath, report: outPath},
  }, null, 2));
  if (blockers > 0) process.exitCode = 2;
}

main();
