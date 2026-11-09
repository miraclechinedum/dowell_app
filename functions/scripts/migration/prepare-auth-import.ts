import {parseArgs, pathArg, readPrivateJson, writePrivateJson} from "./common.js";
import {Decisions} from "./plan.js";

// OFFLINE. Removes closed and excluded accounts (client decisions) from a
// `firebase auth:export --format=json` file before `firebase auth:import`, so
// closed accounts are never recreated in the target. Prints counts only.
//
// Usage (defaults under ~/DowellMigration):
//   node lib/scripts/migration/prepare-auth-import.js [--in=auth-export.json] \
//     [--decisions=decisions.json] [--out=auth-import.json]

interface AuthExport {
  users: {localId: string}[];
}

function main(): void {
  const args = parseArgs();
  const exported = readPrivateJson<AuthExport>(pathArg(args, "in", "auth-export.json"));
  const decisions = readPrivateJson<Decisions>(pathArg(args, "decisions", "decisions.json"));
  if (!Array.isArray(exported.users)) throw new Error("Not a Firebase Auth JSON export.");
  const closed = new Set([
    ...(decisions.closedAccounts ?? []).map((account) => account.uid),
    ...(decisions.excludedAccounts ?? []).map((account) => account.uid),
  ]);
  const kept = exported.users.filter((user) => !closed.has(user.localId));
  const removed = exported.users.length - kept.length;
  writePrivateJson(pathArg(args, "out", "auth-import.json"), {...exported, users: kept});
  console.log(JSON.stringify({
    exported: exported.users.length, removedClosedOrExcluded: removed, toImport: kept.length,
    closedOrExcludedNotFoundInExport: closed.size - removed,
  }, null, 2));
  if (closed.size !== removed) process.exitCode = 2;
}

main();
