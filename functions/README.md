# Dowell Firebase Functions

This directory contains trusted referral, employee-task, account-deletion, and role-management code. Nothing here is deployed by initialization or local tests.

## Role-claim backfill

The callable functions require an existing `admin: true` Firebase Auth custom claim. Bootstrap only explicitly reviewed existing administrator UIDs from a trusted developer workstation authenticated with Application Default Credentials:

```sh
cd functions
npm run build
GOOGLE_CLOUD_PROJECT=dowell-pest-control node lib/scripts/bootstrap-admin.js UID_1 UID_2
```

That command is a dry run. After reviewing its proposed canonical claims, add
`--apply` to perform the changes. The script reads each explicit UID's Firestore
role, refuses ambiguous roles, preserves unrelated claims, and clears conflicting
privileged booleans.

The profile-default migration is also dry-run-first:

```sh
GOOGLE_CLOUD_PROJECT=dowell-pest-control node lib/scripts/backfill-user-profiles.js
# add --apply only after reviewing every update and manual-review row
```

Before enforcing same-customer duplicate referral protection over historical
data, review `lib/scripts/backfill-referral-identities.js` in dry-run mode. It
reports conflicting legacy identities for manual review and writes only when
`--apply` is supplied.

Do not place service-account JSON files or UIDs in this repository. Verify every UID in Firebase Auth and the existing `users/{uid}` admin profile before running the command. This script is intentionally never exposed as an HTTP or callable function.

Affected users must sign out/in or force-refresh their Firebase ID token before
new claims appear. Before rollout, dry-run/review both tools, deploy Functions,
apply reviewed claims/profile defaults, release the compatible Flutter client,
and only then deploy the tightened rules in a coordinated maintenance window.
