import {applicationDefault, initializeApp} from "firebase-admin/app";
import {Auth, UserImportRecord, UserRecord, getAuth} from "firebase-admin/auth";
import {
  SOURCE_PROJECT, parseArgs, pathArg, readPrivateJson, requireApprovalForApply, writeTarget,
} from "./common.js";
import {Decisions} from "./plan.js";

// Imports Firebase Auth users from the legacy project into the target with
// their UIDs, password hashes, verification/disabled state and metadata.
// Replaces `firebase auth:import`, which needs the hash key on the command line.
//
// - The source's scrypt hash parameters are read from its Identity Toolkit
//   config and held in memory only; they are never printed or written.
// - Closed and excluded accounts (decisions) are never imported.
// - UIDs that already exist in the target are skipped, never overwritten.
// - Custom claims are not copied; apply-claims sets them from policy.
// - Dry run by default; --apply needs approved decisions and --confirm-target.
// Output: counts and error codes only.
//
// Usage:
//   node lib/scripts/migration/import-auth-users.js --target=dowell-pest-control-prod \
//     [--decisions=…] [--apply --confirm-target=dowell-pest-control-prod]

interface HashConfig {algorithm?: string; signerKey?: string; saltSeparator?: string; rounds?: number; memoryCost?: number}

async function listAll(auth: Auth): Promise<UserRecord[]> {
  const users: UserRecord[] = [];
  let pageToken: string | undefined;
  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

async function sourceHashConfig(quotaProject: string): Promise<HashConfig> {
  const token = await applicationDefault().getAccessToken();
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/admin/v2/projects/${SOURCE_PROJECT}/config`,
    {headers: {"Authorization": `Bearer ${token.access_token}`, "x-goog-user-project": quotaProject}},
  );
  if (!response.ok) throw new Error(`Could not read source hash configuration (HTTP ${response.status}).`);
  const config = await response.json() as {signIn?: {hashConfig?: HashConfig}};
  return config.signIn?.hashConfig ?? {};
}

async function main(): Promise<void> {
  const args = parseArgs();
  const {project, apply} = writeTarget(args);
  const decisions = readPrivateJson<Decisions>(pathArg(args, "decisions", "decisions.json"));
  requireApprovalForApply(apply, decisions);
  const skip = new Set([
    ...(decisions.closedAccounts ?? []).map((account) => account.uid),
    ...(decisions.excludedAccounts ?? []).map((account) => account.uid),
  ]);

  const source = getAuth(initializeApp({credential: applicationDefault(), projectId: SOURCE_PROJECT}, "auth-source"));
  const target = getAuth(initializeApp({credential: applicationDefault(), projectId: project}, "auth-target"));
  const [sourceUsers, targetUsers, hash] = await Promise.all([
    listAll(source), listAll(target), sourceHashConfig(project),
  ]);

  const problems: Record<string, number> = {};
  const problem = (code: string) => (problems[code] = (problems[code] ?? 0) + 1);
  const hashReady = hash.algorithm === "SCRYPT" && !!hash.signerKey && !!hash.saltSeparator &&
    typeof hash.rounds === "number" && typeof hash.memoryCost === "number";
  if (!hashReady) problem("source-hash-config-incomplete");
  for (const uid of skip) if (!sourceUsers.some((user) => user.uid === uid)) problem("closed-or-excluded-uid-not-in-source");

  const targetIds = new Set(targetUsers.map((user) => user.uid));
  const records: UserImportRecord[] = [];
  let alreadyPresent = 0;
  for (const user of sourceUsers) {
    if (skip.has(user.uid)) continue;
    if (targetIds.has(user.uid)) {
      alreadyPresent++;
      continue;
    }
    const usesPassword = user.providerData.some((provider) => provider.providerId === "password");
    if (usesPassword && (!user.passwordHash || !user.passwordSalt)) {
      problem("password-user-without-exported-hash");
      continue;
    }
    if (Object.keys(user.customClaims ?? {}).length > 0) problem("source-claims-not-copied");
    records.push({
      uid: user.uid, email: user.email, emailVerified: user.emailVerified, disabled: user.disabled,
      displayName: user.displayName, photoURL: user.photoURL, phoneNumber: user.phoneNumber,
      metadata: {creationTime: user.metadata.creationTime, lastSignInTime: user.metadata.lastSignInTime},
      providerData: user.providerData.map((provider) => ({
        uid: provider.uid, providerId: provider.providerId, email: provider.email,
        displayName: provider.displayName, photoURL: provider.photoURL, phoneNumber: provider.phoneNumber,
      })),
      ...(usesPassword ? {
        passwordHash: Buffer.from(user.passwordHash as string, "base64"),
        passwordSalt: Buffer.from(user.passwordSalt as string, "base64"),
      } : {}),
    });
  }

  const blocking = Object.keys(problems).filter((code) => code !== "source-claims-not-copied");
  const result = {imported: 0, failed: 0, errorCodes: {} as Record<string, number>};
  if (apply) {
    if (blocking.length > 0) throw new Error(`Refusing to apply: ${blocking.join(", ")}.`);
    for (let offset = 0; offset < records.length; offset += 1000) {
      const outcome = await target.importUsers(records.slice(offset, offset + 1000), {
        hash: {
          algorithm: "SCRYPT",
          key: Buffer.from(hash.signerKey as string, "base64"),
          saltSeparator: Buffer.from(hash.saltSeparator as string, "base64"),
          rounds: hash.rounds as number,
          memoryCost: hash.memoryCost as number,
        },
      });
      result.imported += outcome.successCount;
      result.failed += outcome.failureCount;
      for (const item of outcome.errors) {
        const code = item.error.code ?? "unknown";
        result.errorCodes[code] = (result.errorCodes[code] ?? 0) + 1;
      }
    }
  }

  console.log(JSON.stringify({
    mode: apply ? "apply" : "dry-run", target: project,
    sourceUsers: sourceUsers.length, closedOrExcludedSkipped: sourceUsers.filter((user) => skip.has(user.uid)).length,
    alreadyInTargetSkipped: alreadyPresent, toImport: records.length,
    passwordUsers: records.filter((record) => record.passwordHash).length,
    sourceHash: {algorithm: hash.algorithm ?? null, parametersPresent: hashReady},
    targetUsersBefore: targetUsers.length, problems,
    ...(apply ? {result} : {}),
  }, null, 2));
  if (blocking.length > 0 || result.failed > 0) process.exitCode = 2;
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
