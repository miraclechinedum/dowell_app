import assert from "node:assert/strict";
import {after, beforeEach, describe, it} from "node:test";
import {deleteApp, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {
  REFERRAL_REWARD_FALLBACK,
  submitReferralForUser,
  validateReferralInput,
} from "../src/referrals.js";

const app = initializeApp({projectId: "demo-dowell"}, "referral-tests");
const db = getFirestore(app);
const auth = {uid: "alice", token: {email: "alice@example.com"}};
const input = {
  requestId: "request_1234567890",
  referralName: " Referred Person ",
  referralEmail: " PERSON@Example.com ",
  referralPhone: "+1 (555) 123-4567",
  address: "123 Example Street",
  serviceType: "residential",
  notes: " Evening appointment ",
};

async function seedUser(overrides: Record<string, unknown> = {}) {
  await db.collection("users").doc("alice").set({
    name: "Alice", email: "profile@example.com", status: "active",
    needsVerification: false, bugBucks: 10, totalReferrals: 2, ...overrides,
  });
}

async function clear() {
  for (const name of [
    "users", "referrals", "referral_identities", "bugbucks_transactions", "app_settings",
  ]) {
    const snapshot = await db.collection(name).get();
    await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
  }
}

describe("submitReferral backend", () => {
  beforeEach(async () => clear());
  after(async () => {
    await clear();
    await deleteApp(app);
  });

  it("rejects unauthenticated and client-authored trusted fields", async () => {
    await assert.rejects(() => submitReferralForUser(db, undefined, input),
      (error: HttpsError) => error.code === "unauthenticated");
    assert.throws(() => validateReferralInput({...input, customerId: "mallory"}),
      (error: HttpsError) => error.code === "invalid-argument");
    assert.throws(() => validateReferralInput({...input, bugBucksAwarded: 9999}),
      (error: HttpsError) => error.code === "invalid-argument");
    assert.throws(() => validateReferralInput({...input, referralName: ""}),
      (error: HttpsError) => error.code === "invalid-argument");
    assert.throws(() => validateReferralInput({...input, referralEmail: "invalid"}),
      (error: HttpsError) => error.code === "invalid-argument");
  });

  it("creates the compatible referral, deterministic ledger, and counters atomically", async () => {
    await seedUser();
    await db.collection("app_settings").doc("reward_settings")
      .set({referral_bug_bucks: 125});
    const result = await submitReferralForUser(db, auth, input);
    assert.equal(result.bugBucksAwarded, 125);
    const referral = await db.collection("referrals").doc(result.referralId).get();
    assert.equal(referral.get("customerId"), "alice");
    assert.equal(referral.get("customerEmail"), "alice@example.com");
    assert.equal(referral.get("referralEmail"), "person@example.com");
    assert.equal(referral.get("status"), "pending");
    assert.equal(referral.get("rewardState"), "completed");
    const ledger = await db.collection("bugbucks_transactions")
      .doc(`referral_${result.referralId}`).get();
    assert.equal(ledger.get("balanceBefore"), 10);
    assert.equal(ledger.get("balanceAfter"), 135);
    const user = await db.collection("users").doc("alice").get();
    assert.equal(user.get("bugBucks"), 135);
    assert.equal(user.get("totalReferrals"), 3);
  });

  it("makes concurrent first calls and later retries exactly once", async () => {
    await seedUser();
    const concurrent = await Promise.all(Array.from({length: 6},
      () => submitReferralForUser(db, auth, input)));
    const first = concurrent[0];
    const retry = await submitReferralForUser(db, auth, input);
    assert.deepEqual(retry, first);
    assert.equal(concurrent.every((result) => result.referralId === first.referralId), true);
    assert.equal((await db.collection("referrals").get()).size, 1);
    assert.equal((await db.collection("bugbucks_transactions").get()).size, 1);
    assert.equal((await db.collection("users").doc("alice").get()).get("totalReferrals"), 3);
  });

  it("does not replay a reward after a referral is soft deleted", async () => {
    await seedUser();
    const result = await submitReferralForUser(db, auth, input);
    await db.collection("referrals").doc(result.referralId).update({isDeleted: true});
    await seedUser({status: "deleted", isDeleted: true, bugBucks: 110, totalReferrals: 3});
    await assert.rejects(() => submitReferralForUser(db, auth, input),
      (error: HttpsError) => error.code === "failed-precondition");
    assert.equal((await db.collection("bugbucks_transactions").get()).size, 1);
    await assert.rejects(() => submitReferralForUser(db, auth, {
      ...input, requestId: "request_after_delete_123", referralName: "Same Person Again",
    }));
    assert.equal((await db.collection("bugbucks_transactions").get()).size, 1);
  });

  it("uses 100 for missing or malformed settings", async () => {
    await seedUser();
    const missing = await submitReferralForUser(db, auth, input);
    assert.equal(missing.bugBucksAwarded, REFERRAL_REWARD_FALLBACK);
    await clear();
    await seedUser();
    await db.collection("app_settings").doc("reward_settings")
      .set({referral_bug_bucks: "lots"});
    const malformed = await submitReferralForUser(db, auth, {...input, requestId: "request_0987654321"});
    assert.equal(malformed.bugBucksAwarded, REFERRAL_REWARD_FALLBACK);
    await clear();
    await seedUser();
    await db.collection("app_settings").doc("reward_settings")
      .set({referral_bug_bucks: 0});
    const zero = await submitReferralForUser(db, auth, {...input, requestId: "request_zero_123456"});
    assert.equal(zero.bugBucksAwarded, REFERRAL_REWARD_FALLBACK);
  });

  it("binds request ID to its normalized payload", async () => {
    await seedUser();
    await submitReferralForUser(db, auth, input);
    await assert.rejects(
      () => submitReferralForUser(db, auth, {...input, referralName: "Another Person"}),
      (error: HttpsError) => error.code === "already-exists");
  });

  it("blocks same-customer duplicate email or normalized phone", async () => {
    await seedUser();
    await submitReferralForUser(db, auth, input);
    await assert.rejects(() => submitReferralForUser(db, auth, {
      ...input, requestId: "request_email_123456", referralPhone: "5559998888",
    }), (error: HttpsError) => error.code === "already-exists");
    await assert.rejects(() => submitReferralForUser(db, auth, {
      ...input, requestId: "request_phone_123456", referralEmail: "other@example.com",
      referralPhone: "1-555-123-4567",
    }), (error: HttpsError) => error.code === "already-exists");
    assert.equal((await db.collection("referrals").get()).size, 1);
  });

  it("allows different customers to refer the same person", async () => {
    await seedUser();
    await db.collection("users").doc("bob").set({
      status: "active", needsVerification: false, bugBucks: 0, totalReferrals: 0,
    });
    await submitReferralForUser(db, auth, input);
    const bob = await submitReferralForUser(db,
      {uid: "bob", token: {email: "bob@example.com"}}, input);
    assert.ok(bob.referralId);
    assert.equal((await db.collection("referrals").get()).size, 2);
  });

  it("concurrent different request IDs for one identity award once", async () => {
    await seedUser();
    const calls = ["request_concurrent_a", "request_concurrent_b"].map((requestId) =>
      submitReferralForUser(db, auth, {...input, requestId}));
    const settled = await Promise.allSettled(calls);
    assert.equal(settled.filter((result) => result.status === "fulfilled").length, 1);
    assert.equal((await db.collection("referrals").get()).size, 1);
    assert.equal((await db.collection("bugbucks_transactions").get()).size, 1);
  });

  it("aborts rather than overwriting malformed legacy balance", async () => {
    await seedUser({bugBucks: "50"});
    await assert.rejects(() => submitReferralForUser(db, auth, input),
      (error: HttpsError) => error.code === "failed-precondition");
    assert.equal((await db.collection("referrals").get()).empty, true);
    assert.equal((await db.collection("users").doc("alice").get()).get("bugBucks"), "50");
  });

  it("leaves no split-brain state when eligibility fails", async () => {
    await seedUser({status: "pending"});
    await assert.rejects(() => submitReferralForUser(db, auth, input),
      (error: HttpsError) => error.code === "failed-precondition");
    assert.equal((await db.collection("referrals").get()).empty, true);
    assert.equal((await db.collection("bugbucks_transactions").get()).empty, true);
    assert.equal((await db.collection("users").doc("alice").get()).get("bugBucks"), 10);
  });
});
