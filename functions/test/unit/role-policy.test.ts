import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  isAllowedRequestedRole,
  isAllowedRole,
} from "../../src/role-policy.js";

describe("role policy", () => {
  it("strictly whitelists assignable roles", () => {
    assert.equal(isAllowedRole("customer"), true);
    assert.equal(isAllowedRole("employee"), true);
    assert.equal(isAllowedRole("admin"), true);
    assert.equal(isAllowedRole("superadmin"), false);
    assert.equal(isAllowedRole(""), false);
  });

  it("only permits employee through the customer request workflow", () => {
    assert.equal(isAllowedRequestedRole("employee"), true);
    assert.equal(isAllowedRequestedRole("admin"), false);
    assert.equal(isAllowedRequestedRole("customer"), false);
  });
});
