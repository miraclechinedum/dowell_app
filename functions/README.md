# Dowell Firebase Functions

This directory contains trusted referral, employee-task, account-deletion, and role-management code. Nothing here is deployed by initialization or local tests.

## ⚠️ Legacy maintenance scripts (do not run without written approval)

`scripts/bootstrap-admin.ts`, `scripts/backfill-user-profiles.ts` and
`scripts/backfill-referral-identities.ts` are **legacy** scripts written before
the production migration. They write custom claims, profile fields or referral
identity reservations when given `--apply`.

They are now guarded by `scripts/legacy-target.ts`, which runs before Firebase is
initialized:

- `--project=<id>` is **required on every run** and must be an approved target.
  The legacy project **`dowell-pest-control` is always refused** and must remain
  unchanged. Unknown or retired projects are refused.
- Writes need `--apply` **and** `--confirm-target=<id>` exactly matching `--project`.
- If `GOOGLE_CLOUD_PROJECT`, `GCLOUD_PROJECT`, `GCP_PROJECT` or `FIREBASE_CONFIG`
  name a different project, the script refuses. The initialized app's project is
  re-checked before any read or write.

The production migration is complete; account activation and admin access are
owner decisions. **Do not run these scripts against production without separate
written approval.** If a run is approved, review a dry run first. Placeholders are
intentional; never copy a real project ID from older notes:

```sh
# DRY RUN (read-only): prints proposed changes only
node lib/scripts/<script>.js --project=<APPROVED_PROJECT_ID> [args]

# WRITE: only after reviewing the dry run and receiving written approval
node lib/scripts/<script>.js --project=<APPROVED_PROJECT_ID> --apply \
  --confirm-target=<APPROVED_PROJECT_ID> [args]
```

## ⚠️ Storage token probe (disabled)

`scripts/verify-storage-token-revocation.ts` **removes the download token** from a
Storage object. It is guarded by `scripts/storage-probe-guard.ts`, which validates
arguments before Firebase is initialized:

- Buckets must be on `APPROVED_PROBE_BUCKETS` in that source file. The list is
  **empty**, so the probe refuses every request. It cannot be extended from the
  command line; approving a bucket needs a reviewed code change with a written
  approval reference for that exact bucket and operation.
- The legacy and production default buckets additionally need a separate
  `protectedBucketApprovalReference`.
- `--confirm-bucket=<bucket>` must match `--bucket` exactly. `--confirm-staging`
  is no longer accepted.

## Migration tools (`scripts/migration/`)

These tools have their own, stricter checks:

- Write-capable tools (`import-auth-users`, `migrate-firestore`, `migrate-storage`,
  `apply-claims`, `provision-client-admin`) accept only the production destination
  as `--target`, refuse the legacy project, and run as **dry runs** unless given
  **all** of: `--apply`, an exact matching `--confirm-target`, and an approved
  private decisions file. Provisioning the client admin also requires
  `clientAdmin.approved`. These checks run before any Firebase connection
  (covered by `test/unit/migration-guards.test.ts`).
- The legacy project is only ever read (`snapshot-source`, and the source side of
  `import-auth-users` and `validate-target`).
- The migration was executed on 2026-10-22. Its decisions file is set to
  `approved: false`, with a read-only archive of the executed decisions.

### Migration lock

Every write-capable migration tool also checks a fixed lock file,
`~/DowellMigration/migration-lock.json`, **before** any Firebase connection,
whichever `--decisions` file is passed. An archived, approved decisions file
therefore cannot bypass it. The check fails closed: a missing, unreadable,
malformed, symlinked or group/world-writable lock file refuses `--apply`.
Dry runs, `plan-report` and `validate-target` are unaffected. There is no
command-line override.

Manual unlock procedure (only for a separately approved future migration):

1. Obtain written approval that names the migration and its scope.
2. Edit the lock file by hand (owner-only, mode `600`) to
   `{"locked": false, "unlockApproval": {"reference": "<approval reference>",
   "approvedBy": "<name or role>", "approvedOn": "<YYYY-MM-DD>"}}`.
   All three fields are required.
3. Run the tools (dry run first), then restore `"locked": true` immediately afterwards.

## General

Do not place service-account JSON files, exports or UIDs in this repository
(`.gitignore` blocks common names). Users must sign out and in, or force-refresh
their ID token, before changed custom claims take effect.
