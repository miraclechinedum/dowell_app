import assert from "node:assert/strict";
import {test} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import {requireAdmin} from "../../src/index.js";

test("reconciliation authorization requires an admin custom claim", () => {
  assert.throws(() => requireAdmin({}),
    (error: HttpsError) => error.code === "unauthenticated");
  assert.throws(() => requireAdmin({auth: {uid: "customer", token: {}}}),
    (error: HttpsError) => error.code === "permission-denied");
  assert.equal(requireAdmin({auth: {uid: "admin", token: {admin: true}}}), "admin");
});
