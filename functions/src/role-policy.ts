export const allowedRoles = new Set(["customer", "employee", "admin"]);
export const allowedRequestedRoles = new Set(["employee"]);

export function isAllowedRole(role: string): boolean {
  return allowedRoles.has(role);
}

export function isAllowedRequestedRole(role: string): boolean {
  return allowedRequestedRoles.has(role);
}
