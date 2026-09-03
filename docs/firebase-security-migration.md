# Firebase security migration

This is a local migration plan. Deploy Functions and bootstrap reviewed admin claims before deploying the prepared Firestore rules.

## `users/{uid}` field authority

| Fields | Client owner | Admin client with custom claim | Trusted Functions | Current caller / note |
| --- | --- | --- | --- | --- |
| `displayName`, `name`, `email`, `phone`, `address`, `photoURL`, `updatedAt` | Update own profile | Allowed | Allowed | Ordinary profile/admin profile editing |
| `role` | Create only as `customer`; no update | Allowed by rules, but Flutter role assignment now calls Functions | Authoritative | Authorization comes from Auth custom claims; Firestore is display/profile synchronization only |
| `needsVerification`, `requestedRole`, `status` | Only exact customer transition from active/no request to pending employee request | Allowed | Authoritative for review | `requestRoleUpgrade`; review Function clears request and restores active status |
| `bugBucks`, `totalReferrals`, `convertedReferrals` | No update; optional zero only on profile creation | Allowed | Intended authority | Active referral client reward update will be denied until migrated |
| `cashBonusBalance`, `cashBalance` | No update to protected bonus balance | Allowed | Intended authority | Admin task approval currently updates bonus balance |
| `pendingTasks`, `totalTasks` | No update to protected task totals | Allowed | Intended authority | Employee task submission currently updates both and requires later backend migration |
| `approvedBy`, `approvedAt`, `approvalNotes` | Never | Allowed | Authoritative | Role approval Function writes these |
| `rejectedBy`, `rejectedAt`, `rejectionReason` | Never | Allowed | Authoritative | Role rejection Function writes these |
| `previousRole`, `roleUpdatedBy`, `roleUpdatedAt`, `roleChangeReason` | Never | Allowed | Authoritative | Manual role-management Function writes these |
| `statusUpdatedBy`, `statusUpdatedByEmail`, `statusUpdatedAt`, `statusReason`, activation/deactivation timestamps | Never | Allowed | Future migration target | Current admin user-management UI |
| `createdAt` | Set during constrained customer profile creation | Allowed | Allowed | Registration/profile initialization |
| `referralCode` | Existing profiles retain it; no owner updates | Allowed | Legacy data only | All client generators were removed |

## Legacy cleanup status

- Obsolete client-side referral/reward writes, Firebase initialization,
  referral-code generation, and global-setting seeding were removed.
- Referral rewards and employee-task counters now use trusted transactional
  callable Functions. Historical data still requires the documented dry-run
  migrations and review before rules rollout.
