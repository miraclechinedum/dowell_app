// Profile status defaults shared by backfill-user-profiles and the migration
// planner, so both apply identical rules. Pure: no Firebase access.

export interface RoleRequestContext {
  /** An approved role request exists for this user and requested `role`. */
  approvedRequestForRole: boolean;
  /** The user has a role request that is still pending. */
  pendingRequest: boolean;
}

export type ProfileDefaults =
  | {kind: "update"; update: Record<string, unknown>; resolvedRequestedRole?: unknown}
  | {kind: "review"; reason: "missing-status" | "missing-verification"};

/**
 * Original backfill rules: a missing status becomes "active" unless the profile
 * shows any sign of a pending or restricted state, which needs manual review.
 *
 * With `context`, one extra case is resolved automatically: a stale
 * `requestedRole` equal to the profile's current role, backed by an approved
 * role request and no pending request, means the request was already granted.
 */
export function profileDefaults(data: Record<string, unknown>, context?: RoleRequestContext): ProfileDefaults {
  const resolvesStaleRequest = context !== undefined && data.status == null &&
    data.requestedRole != null && data.requestedRole === data.role &&
    context.approvedRequestForRole && !context.pendingRequest &&
    data.needsVerification !== true && data.isDeleted !== true;
  const requestedRole = resolvesStaleRequest ? null : data.requestedRole;

  const update: Record<string, unknown> = {};
  const knownUnsafe = data.status === "pending" || data.status === "deactivated" ||
    data.status === "blocked" || data.needsVerification === true || requestedRole != null;
  if (data.status == null) {
    if (knownUnsafe) return {kind: "review", reason: "missing-status"};
    update.status = "active";
  }
  if (data.needsVerification == null) {
    if (data.status === "pending" || requestedRole != null) {
      update.needsVerification = true;
    } else if (data.status === "active" || update.status === "active") {
      update.needsVerification = false;
    } else {
      return {kind: "review", reason: "missing-verification"};
    }
  }
  return resolvesStaleRequest ?
    {kind: "update", update, resolvedRequestedRole: data.requestedRole} :
    {kind: "update", update};
}
