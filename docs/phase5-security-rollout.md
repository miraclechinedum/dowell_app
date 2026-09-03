# Phase 5 security rollout

## Accounting and account deletion

`bugbucks_transactions` is the canonical Bug Bucks accounting history.
`users.bugBucks` is the trusted-server-maintained current-balance cache, while
`referrals.bugBucksAwarded` records the reward associated with one referral.
Referral totals in referral analytics are earned-from-referrals metrics, not a
live wallet balance.

`deleteMyAccountData` requires a token authenticated within the previous five
minutes. It deletes disposable role requests, notifications, and legacy cashout
requests. It retains and anonymizes referrals, employee tasks, and Bug Bucks/cash
bonus ledgers so accounting structure remains intact without contact/profile PII.
It then deletes the profile and Firebase Auth user. This is a technical retention
classification, not a statement of legal retention requirements. Evidence files
in Storage need an explicit product retention decision before production rollout.

## Referral identity and legacy data

The backend reserves deterministic SHA-256 identities separately for normalized
email and phone, scoped by customer UID. Either matching reservation blocks a
second reward for that customer; another customer has different reservations.
If email and phone point at different existing reservations, submission fails
safely. Existing referrals are not automatically reserved at runtime.
`backfill-referral-identities.ts` provides the dry-run-first migration; conflicts
must be reviewed before `--apply` and before rules rollout.

## Claims, demotion, and tokens

Canonical role claims always contain `role`, `admin`, and `employee`, with exactly
one role and matching booleans. Unrelated claims are preserved. Removing either
privileged boolean revokes refresh tokens. An access token already issued before
revocation remains valid until expiry; Firestore rules cannot observe revocation
without an online token refresh. An `auth_time` rules lookup would add operational
state and is not introduced here. The app force-refreshes once when profile and
claim role differ, then routes only from boolean claims; persistent mismatch
requires sign-out/sign-in and never grants profile-based authority.

## Migration tools

`backfill-user-profiles.ts` and `bootstrap-admin.ts` are dry-run by default and
require `--apply` for writes. The claim tool requires explicit UIDs and refuses
missing/ambiguous Firestore roles. Neither script embeds credentials. Review all
dry-run output and ambiguous profiles before any production execution.

## App Check preparation

Do not enforce App Check while version `1.0.0+8` is active because it sends no App
Check token. Phase 6 sequence:

1. Add `firebase_app_check` to Flutter, configure Play Integrity on Android and
   App Attest with an appropriate DeviceCheck fallback on iOS; use registered
   debug providers/tokens only in development.
2. Release the compatible app with enforcement still disabled and observe token
   adoption and callable/error telemetry.
3. Allow a sufficient upgrade window and decide how unsupported versions are
   handled.
4. Enable enforcement service-by-service, beginning with trusted callables, while
   monitoring rejection rates and retaining a rollback plan.
