# Referral reward architecture

`submitReferral` is the sole trusted creation path for rewarded referrals. The
Flutter client sends referral form fields plus a request ID; it cannot choose
ownership, status, reward amount, balances, counters, timestamps, or ledger data.

The referral document ID is the SHA-256 digest of `uid:requestId`. Its reward
ledger ID is `referral_<referralId>`. One Firestore transaction reads the user,
setting, referral, and ledger, then creates both records and updates the user's
balance and referral count. A completed referral and its deterministic ledger
are the exactly-once invariant. A retry returns the stored amounts; an incomplete
or inconsistent pair fails without applying another credit.

The reward source is `app_settings/reward_settings.referral_bug_bucks`. Missing,
non-integer, negative, or otherwise malformed values fall back to 100 Bug Bucks.

Legacy referral documents keep working because the established field names and
screen defaults are preserved. New documents add request/reward metadata and
normalized email/phone values.

Historical partial submissions are not rewritten in this phase. A future
privileged, dry-run-first reconciliation should identify referrals without a
matching ledger, compare each user's referral ledgers with their stored balance
and counters, and write an auditable repair exactly once. It must not infer that
every legacy referral deserves another credit solely because new reward metadata
is absent.

Technical retries are deduplicated indefinitely by request ID for each customer.
No business-level duplicate rejection is currently applied. Product guidance is
needed to define a time window and treatment of repeated referrals by the same
customer before such a policy is added; two different customers should not be
globally conflated by that future check.
