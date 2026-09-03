import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {canonicalRoleClaims} from "../../src/role-claims.js";

describe("canonical role claims", () => {
  it("preserves unrelated claims and clears conflicting booleans", () => {
    assert.deepEqual(canonicalRoleClaims("admin", {employee: true, tenant: "dowell"}), {
      role: "admin", admin: true, employee: false, tenant: "dowell",
    });
    assert.deepEqual(canonicalRoleClaims("employee", {admin: true}), {
      role: "employee", admin: false, employee: true,
    });
    assert.deepEqual(canonicalRoleClaims("customer", {admin: true, employee: true}), {
      role: "customer", admin: false, employee: false,
    });
  });
});
