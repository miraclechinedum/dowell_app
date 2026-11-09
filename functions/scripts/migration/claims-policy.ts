import {canonicalRoleClaims} from "../../src/role-claims.js";

export type ClaimDecision =
  | {kind: "set"; claims: Record<string, unknown>}
  | {kind: "held"; reason: string};

/**
 * Maps a migrated profile role to custom claims. Unsupported roles are never
 * converted, and admin claims require an explicitly approved UID.
 */
export function claimDecision(
  uid: string, role: unknown, existing: Record<string, unknown>, approvedAdmins: Set<string>,
  status: unknown,
): ClaimDecision {
  if (role === undefined || role === null) return {kind: "held", reason: "missing-role"};
  if (role === "admin" && !approvedAdmins.has(uid)) return {kind: "held", reason: "admin-not-approved"};
  if (role !== "customer" && role !== "employee" && role !== "admin") {
    return {kind: "held", reason: `unsupported-role:${String(role)}`};
  }
  // Claims are only issued to profiles that are already active; activation is
  // an owner decision, never a side effect of claim assignment.
  if (status !== "active") return {kind: "held", reason: "status-not-active"};
  return {kind: "set", claims: canonicalRoleClaims(role, existing)};
}

/** Held outcomes that are the approved policy, not validation failures. */
export const POLICY_HELD_REASONS = new Set(["admin-not-approved", "status-not-active"]);

/** Closed-account placeholder profiles never receive claims. */
export function isClosedProfile(profile: {status?: unknown; isDeleted?: unknown}): boolean {
  return profile.status === "deleted" || profile.isDeleted === true;
}

/**
 * Approved admin UIDs: those listed in the decisions, plus the profile created
 * for the approved client admin email (its UID only exists after provisioning).
 */
export function approvedAdminSet(
  decisions: {approvedAdminUids: string[]; clientAdmin?: {email: string; approved: boolean}},
  profiles: {id: string; email?: unknown; provisionedClientAdmin?: unknown}[],
): Set<string> {
  const approved = new Set(decisions.approvedAdminUids);
  const client = decisions.clientAdmin;
  if (client?.approved) {
    for (const profile of profiles) {
      if (profile.provisionedClientAdmin === true && typeof profile.email === "string" &&
          profile.email.toLowerCase() === client.email.toLowerCase()) {
        approved.add(profile.id);
      }
    }
  }
  return approved;
}

export function sameRoleClaims(a: Record<string, unknown>, b: Record<string, unknown>): boolean {
  return a.role === b.role && a.admin === b.admin && a.employee === b.employee;
}
