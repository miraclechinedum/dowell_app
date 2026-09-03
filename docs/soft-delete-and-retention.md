# Soft deletion and audit retention

## Convention

Operational documents use trusted deletion metadata:

- `isDeleted: true`
- `deletedAt`: server timestamp
- `deletedBy`: authenticated actor UID or trusted system identifier
- `deletedSource`: `self`, `admin`, or `system`
- `deletionReason`: optional and constrained when an archive callable accepts it

Missing `isDeleted` and `isDeleted: false` both mean active. This preserves legacy
records without a mandatory backfill. New referral, employee-task, and role-request
records explicitly set `isDeleted: false`. Clients may not author protected deletion
metadata. Physical deletes are denied by version-controlled rules.

## Collection policy

| Collection | Policy |
| --- | --- |
| `users` | Retained with `status: deleted`, soft-delete metadata, and Auth sync state. |
| `referrals` | Soft-deleted for operational UI; request ID, payload hash, reward linkage, and identity reservations remain authoritative. |
| `referral_identities` | Retained unchanged as permanent hashed dedupe reservations. |
| `employee_tasks` | Soft-deleted for operational UI; request ID and payload hash remain authoritative. |
| `bugbucks_transactions` | Immutable financial history; retained with UID and linkage. |
| `cash_bonus_transactions` | Immutable financial history; retained with UID and linkage. |
| `employee_cashouts` | Retained and soft-deleted from operational use during account deactivation. |
| `role_requests` | Retained and soft-deleted during account deactivation. |
| `notifications` | Retained and soft-deleted during account deactivation; owner dismissal remains a non-destructive update. |
| `audit_logs` | Trusted creation/read only; client/admin update and delete are denied. |

Admin user management hides deleted accounts by default and exposes an explicit
deleted-account history toggle. Other operational admin lists exclude deleted rows.

## Evidence retention

Evidence remains at `task_evidence/{uid}/{requestId}/{fileName}`. Active task documents
may contain temporary legacy URLs, but account deactivation clears `images` and
`imageUrls`; `imagePaths` is the only canonical archived reference. The backend removes
Firebase download-token metadata and marks objects `archived=true` without deleting
them. `storage.rules` denies unauthenticated and cross-employee access, constrains type
and size, prevents client deletion, blocks employee access after archival, and permits
claimed admins to read evidence. The admin task history reads archived objects directly
by path through the authenticated Firebase Storage SDK.

The Storage emulator is not authoritative for download-token invalidation. Before
production rollout, run `verify-storage-token-revocation.ts` only against a throwaway or
staging bucket using explicit `--bucket`, `--object`, and `--confirm-staging` arguments.
Rollout fails if the captured old URL remains accessible. The script embeds no project,
bucket, credential, object, token, or URL.

Storage emulator tests cover owned uploads plus unauthenticated and cross-employee read
denials. Manual rollout validation should additionally verify the deployed bucket name,
admin evidence retrieval, token revocation, and archived-object write denial.

## Migration strategy

No write backfill is required. All Flutter operational queries temporarily fetch their
legacy-compatible result set and filter `isDeleted == true` locally. The read-only
`functions/scripts/audit-soft-delete-readiness.ts` reports missing/active/deleted counts
and must not be run against production during this phase. A later indexed backfill can
set `isDeleted: false` if server-side filtered queries become necessary at scale.

## True erasure

Regulatory/manual erasure is intentionally outside the normal application workflow.
It requires a separately authorized, audited operational process and is not implemented
by `deleteMyAccountData`.

## Real-device deletion QA

1. Sign in to an account with referrals, ledger entries, tasks/evidence, notifications,
   and a role request; record its UID and document IDs.
2. Let the session age beyond five minutes, choose **Delete Account**, and verify the
   first callable returns recent-authentication required.
3. Re-enter the password and retry.
4. Verify `users/{uid}` still exists with `status=deleted`, `isDeleted=true`, and
   `accountDeletionStatus=completed`.
5. Verify the Auth UID still exists, is disabled, and refresh tokens were revoked.
6. Verify the app signs out, pending referral/task local state is cleared, and password
   sign-in is denied.
7. Verify referral/task/role-request/notification/cashout rows still exist but are absent
   from normal operational lists.
8. Verify referral identities and both financial ledgers still exist with their original
   IDs, amounts, timestamps, UIDs, and safe linkages.
9. Clear app data or reinstall, then verify password sign-in is still denied.
10. Verify referrals, ledgers, tasks, identity reservations, and Storage objects remain.
11. Verify archived tasks retain `imagePaths` and expose neither `images` nor `imageUrls`.
12. Test the previously captured URL against real staging Storage; it must fail with
    401/403/404 or another inaccessible response.
13. Verify a claimed admin retrieves archived evidence through authenticated path access.
14. Verify operational user/task/referral screens exclude archived records.
15. Verify the deterministic audit event exists and status is `completed`.
16. Force an ID-token refresh and confirm rejection; inspect Admin Auth to confirm
    `disabled=true` and a later `tokensValidAfterTime`.
17. Repeat the callable in the emulator with a simulated Auth failure; verify
    `accountDeletionStatus=failed`, then retry and verify it becomes `completed`.

## Reconciliation and deleted-employee obligations

Claimed admins call `reconcileAccountDeletion` without a target to list `pending` and
`failed` accounts, then with `targetUid` to idempotently repeat incomplete archival,
token revocation, Auth disablement, and completion. It never restores an account.

Approved unpaid tasks are marked `deletedOwnerTaskState=outstanding_payment` and remain
visible in the admin **Deleted / Unpaid** filter. The admin-only
`settleDeletedEmployeeTaskPayment` callable records one deterministic historical cash
bonus transaction and marks the task settled without reactivating or crediting the
deleted profile. Pending tasks remain `pending_review` for manual disposition.

## Release compatibility

| Combination | Result |
| --- | --- |
| 1.0.0+8 + old rules | Existing released behavior. |
| 1.0.0+8 + new Functions only | Compatible; deploy Functions first. |
| 1.0.0+8 + new Storage rules | Do not roll out before 1.0.1+9 adoption. |
| 1.0.0+8 + new Firestore rules | Do not roll out before 1.0.1+9 adoption. |
| 1.0.1+9 + old rules | Transitional client; retention enforcement is incomplete. |
| 1.0.1+9 + new Functions | Supported transition after Functions-first deployment. |
| 1.0.1+9 + new Firestore + Storage rules | Intended final state after staging probe passes. |

Required order: Functions first, release/adopt 1.0.1+9, then Firestore and Storage rules.
