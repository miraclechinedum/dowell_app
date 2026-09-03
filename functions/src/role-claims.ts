export type CanonicalRole = "customer" | "employee" | "admin";

export function canonicalRoleClaims(
  role: CanonicalRole,
  existing: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    ...existing,
    role,
    admin: role === "admin",
    employee: role === "employee",
  };
}

export function isCanonicalRole(value: unknown): value is CanonicalRole {
  return value === "customer" || value === "employee" || value === "admin";
}
