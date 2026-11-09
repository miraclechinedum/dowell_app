import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {Encoded} from "../../scripts/migration/common.js";
import {profileDefaults} from "../../scripts/profile-defaults.js";
import {approvedAdminSet, claimDecision, isClosedProfile} from "../../scripts/migration/claims-policy.js";
import {
  Decisions, Doc, Snapshot, buildPlan, closedAccountPseudonym, legacyDelta, storagePathFromUrl,
} from "../../scripts/migration/plan.js";

const ts = (seconds: number): Encoded => ({__type: "timestamp", seconds, nanoseconds: 0});

function snapshot(docs: Record<string, Doc>): Snapshot {
  return {
    formatVersion: 1, sourceProject: "dowell-pest-control", takenAt: "2026-10-19T00:00:00Z",
    snapshotId: "a".repeat(64),
    documents: Object.entries(docs).map(([path, data]) => ({path, data})),
    storage: {bucket: "dowell-pest-control.firebasestorage.app", objects: []},
  };
}

const settings = {"app_config/settings": {bugBucksPerReferral: 100, employeeTaskBonus: 25}};

function decisions(overrides: Partial<Decisions> = {}): Decisions {
  return {
    approved: true, cutoverAt: "2026-11-01T00:00:00Z",
    balanceMapping: {
      customer: {bugBucks: "walletBalance", cashBonusBalance: "zero"},
      employee: {bugBucks: "zero", cashBonusBalance: "walletBalance"},
    },
    ledgerMismatchPolicy: "block", pendingPayoutPolicy: "block",
    copyResumes: false, approvedAdminUids: [],
    ...overrides,
  };
}

const codes = (plan: ReturnType<typeof buildPlan>, severity = "blocker") =>
  plan.issues.filter((item) => item.severity === severity).map((item) => item.code).sort();
const written = (plan: ReturnType<typeof buildPlan>, path: string) =>
  plan.writes.find((write) => write.path === path)?.data;

describe("migration plan: balances", () => {
  it("maps a reconciled customer wallet to bugBucks with one opening entry", () => {
    const plan = buildPlan(snapshot({
      ...settings,
      "users/c1": {role: "customer", fullName: "C", walletBalance: 150},
      "transactions/t1": {userId: "c1", type: "referral_bonus", amount: 100, balance: 100, createdAt: ts(1)},
      "transactions/t2": {userId: "c1", type: "admin_adjustment", amount: 50, balance: 150, createdAt: ts(2)},
    }), decisions());
    assert.deepEqual(codes(plan), []);
    const user = written(plan, "users/c1") as Doc;
    assert.equal(user.bugBucks, 150);
    assert.equal(user.cashBonusBalance, 0);
    assert.equal(user.walletBalance, 150, "original field preserved");
    assert.deepEqual(user.legacyBalances, {walletBalance: 150});
    assert.equal(user.displayName, "C");
    const opening = written(plan, "bugbucks_transactions/migration_opening_c1") as Doc;
    assert.equal(opening.balanceAfter, 150);
    assert.ok(written(plan, "transactions/t1"), "legacy ledger archived unchanged");
    assert.equal(written(plan, "cash_bonus_transactions/migration_opening_c1"), undefined);
  });

  it("debits payouts and redemptions regardless of stored sign", () => {
    assert.equal(legacyDelta({type: "payout", amount: -20}), -20);
    assert.equal(legacyDelta({type: "redemption", amount: 30}), -30);
    assert.equal(legacyDelta({type: "mystery", amount: 1}), undefined);
  });

  it("blocks on a ledger mismatch unless the balance field is trusted", () => {
    const docs = {
      ...settings,
      "users/c1": {role: "customer", walletBalance: 90},
      "transactions/t1": {userId: "c1", type: "referral_bonus", amount: 100, balance: 100, createdAt: ts(1)},
    };
    assert.deepEqual(codes(buildPlan(snapshot(docs), decisions())), ["legacy-ledger-mismatch"]);
    const trusted = buildPlan(snapshot(docs), decisions({ledgerMismatchPolicy: "trust-balance-field"}));
    assert.deepEqual(codes(trusted), []);
    assert.deepEqual(codes(trusted, "warning"), ["legacy-ledger-mismatch"]);
  });

  it("never drops a balance: unmapped roles and fields are blockers", () => {
    const plan = buildPlan(snapshot({
      ...settings,
      "users/a1": {role: "athlete", walletBalance: 10},
      "users/c1": {role: "customer", walletBalance: 5, bugBucks: 7},
    }), decisions({ledgerMismatchPolicy: "trust-balance-field"}));
    assert.deepEqual(codes(plan), ["balance-field-unmapped", "balance-mapping-missing"]);
    const superseded = buildPlan(snapshot({
      ...settings, "users/c1": {role: "customer", walletBalance: 5, bugBucks: 7},
    }), decisions({
      ledgerMismatchPolicy: "trust-balance-field",
      balanceMapping: {customer: {bugBucks: "walletBalance", cashBonusBalance: "zero", superseded: ["bugBucks"]}},
    }));
    assert.deepEqual(codes(superseded), []);
    assert.equal((written(superseded, "users/c1") as Doc).bugBucks, 5);
  });

  it("blocks pending payouts unless they are carried as obligations", () => {
    const docs = {
      ...settings,
      "users/e1": {role: "employee", walletBalance: 40},
      "payout_requests/p1": {userId: "e1", amount: 30, status: "pending"},
    };
    const trust = {ledgerMismatchPolicy: "trust-balance-field" as const};
    assert.deepEqual(codes(buildPlan(snapshot(docs), decisions(trust))), ["pending-payouts-present"]);
    const carried = buildPlan(snapshot(docs), decisions({...trust, pendingPayoutPolicy: "carry-as-obligation"}));
    assert.deepEqual(codes(carried), []);
    assert.deepEqual(carried.summary.pendingPayouts, {count: 1, amount: 30});
    assert.equal((written(carried, "cash_bonus_transactions/migration_opening_e1") as Doc).amount, 40);
  });
});

describe("migration plan: owners without a profile", () => {
  const noUidLeak = (plan: ReturnType<typeof buildPlan>, uid: string) =>
    assert.ok(plan.issues.every((item) => !`${item.path ?? ""} ${item.detail ?? ""}`.includes(uid)));

  it("blocks a legacy ledger whose owner has no profile and totals the stranded balance", () => {
    const plan = buildPlan(snapshot({
      ...settings,
      "users/c1": {role: "customer", bugBucks: 0},
      "transactions/t1": {userId: "gone-uid", type: "referral_bonus", amount: 50, balance: 50, createdAt: ts(1)},
      "transactions/t2": {userId: "gone-uid", type: "task_bonus", amount: 10, balance: 60, createdAt: ts(2)},
    }), decisions({ledgerMismatchPolicy: "trust-balance-field", pendingPayoutPolicy: "carry-as-obligation"}));
    assert.deepEqual(codes(plan), ["ledger-owner-profile-missing"]);
    assert.deepEqual((plan.summary.ownerProfileMissing as Doc).legacyLedger, {owners: 1, entries: 2, balance: 60});
    assert.ok(written(plan, "transactions/t1"), "stranded ledger is still archived");
    noUidLeak(plan, "gone-uid");
  });

  it("blocks a pending payout whose owner has no profile, regardless of payout policy", () => {
    const plan = buildPlan(snapshot({
      ...settings,
      "payout_requests/p1": {userId: "gone-uid", amount: 30, status: "pending", method: "bank", accountDetails: "secret"},
      "payout_requests/p2": {userId: "gone-uid", amount: 99, status: "processed"},
    }), decisions({pendingPayoutPolicy: "carry-as-obligation"}));
    assert.deepEqual(codes(plan), ["ledger-owner-profile-missing"]);
    assert.deepEqual((plan.summary.ownerProfileMissing as Doc).pendingPayouts, {count: 1, amount: 30});
    assert.equal(plan.issues.find((item) => item.code === "ledger-owner-profile-missing")?.path, "payout_requests/p1");
    noUidLeak(plan, "gone-uid");
    assert.ok(plan.issues.every((item) => !(item.detail ?? "").includes("secret")));
  });

  it("counts ledger entries without any userId as stranded", () => {
    const plan = buildPlan(snapshot({
      ...settings,
      "transactions/t1": {type: "referral_bonus", amount: 50, balance: 50, createdAt: ts(1)},
    }), decisions());
    assert.deepEqual(codes(plan), ["ledger-owner-profile-missing"]);
    assert.match(plan.issues[0].detail ?? "", /owner=no-userId/);
    assert.deepEqual((plan.summary.ownerProfileMissing as Doc).legacyLedger, {owners: 1, entries: 1, balance: 50});
  });
});

describe("migration plan: records", () => {
  it("maps legacy referral fields additively and links the reward ledger", () => {
    const plan = buildPlan(snapshot({
      ...settings,
      "users/c1": {role: "customer", fullName: "C", email: "c@example.test", walletBalance: 0},
      "referrals/r1": {
        referrerId: "c1", email: "Friend@Example.test", phoneNumber: "+1 (555) 010-0000",
        bugBucksEarned: 0, bugBucksPending: 100, submittedAt: ts(5), status: "pending",
      },
    }), decisions());
    const referral = written(plan, "referrals/r1") as Doc;
    assert.equal(referral.customerId, "c1");
    assert.equal(referral.referrerId, "c1");
    assert.equal(referral.normalizedReferralEmail, "friend@example.test");
    assert.equal(referral.normalizedReferralPhone, "15550100000");
    assert.deepEqual(referral.createdAt, ts(5));
    assert.equal(referral.rewardState, "legacy");
    assert.equal(referral.customerEmail, "c@example.test");
    assert.deepEqual(plan.summary.pendingReferralRewards, {count: 1, amount: 100});
    assert.equal((written(plan, "users/c1") as Doc).totalReferrals, 1);
  });

  it("requires migrated Storage URLs for legacy task photos", () => {
    const url = "https://firebasestorage.googleapis.com/v0/b/dowell-pest-control.firebasestorage.app/o/task_photos%2Ft1%2Fphoto_0.jpg?alt=media&token=x";
    assert.equal(storagePathFromUrl(url), "task_photos/t1/photo_0.jpg");
    const docs = {
      ...settings,
      "users/e1": {role: "employee", walletBalance: 25},
      "employee_tasks/t1": {employeeId: "e1", taskType: "Inspection", photos: [url], status: "approved", bonusAmount: 25, submittedAt: ts(3)},
      "transactions/x": {userId: "e1", type: "task_bonus", amount: 25, balance: 25, createdAt: ts(4)},
    };
    assert.deepEqual(codes(buildPlan(snapshot(docs), decisions())), ["task-photos-not-migrated"]);
    const plan = buildPlan(snapshot(docs), decisions(), {
      bucket: "dowell-pest-control-staging.firebasestorage.app",
      taskPhotos: {t1: [{sourcePath: "task_photos/t1/photo_0.jpg", path: "task_evidence/e1/legacy_t1/photo_0.jpg", url: "https://new"}]},
    });
    assert.deepEqual(codes(plan), []);
    const task = written(plan, "employee_tasks/t1") as Doc;
    assert.deepEqual(task.imagePaths, ["task_evidence/e1/legacy_t1/photo_0.jpg"]);
    assert.deepEqual(task.legacyPhotoUrls, [url]);
    assert.equal(task.cashBonusAwarded, 25);
    assert.equal(task.bonusCreditedToBalance, true);
    assert.equal(task.paidOut, false);
  });

  it("reports photos from a never-provisioned source bucket without blocking", () => {
    const snap = snapshot({
      ...settings,
      "users/e1": {role: "employee"},
      "employee_tasks/t1": {employeeId: "e1", photos: ["https://firebasestorage.googleapis.com/v0/b/x/o/task_photos%2Ft1%2Fp.jpg"], status: "pending", submittedAt: ts(1)},
    });
    snap.storage.exists = false;
    const plan = buildPlan(snap, decisions());
    assert.deepEqual(codes(plan), []);
    assert.deepEqual(codes(plan, "warning"), ["task-photos-unrecoverable"]);
    const task = written(plan, "employee_tasks/t1") as Doc;
    assert.equal(task.imagePaths, undefined);
    assert.equal((task.legacyPhotoUrls as Encoded[]).length, 1);
  });

  it("flags unknown collections and derives reward settings from app_config", () => {
    const plan = buildPlan(snapshot({...settings, "mystery/x": {a: 1}}), decisions());
    assert.deepEqual(codes(plan), ["unclassified-collection"]);
    assert.equal((written(plan, "app_settings/reward_settings") as Doc).referral_bug_bucks, 100);
  });

  it("is deterministic and tags every write", () => {
    const docs = {...settings, "users/c1": {role: "customer", walletBalance: 0}};
    const first = buildPlan(snapshot(docs), decisions());
    const second = buildPlan(snapshot(docs), decisions());
    assert.deepEqual(first.writes.map((w) => w.contentHash), second.writes.map((w) => w.contentHash));
    assert.ok(first.writes.every((w) => (w.data.migration as Doc).contentHash === w.contentHash));
  });
});

describe("migration plan: account closed at client request", () => {
  const EX = "ex-employee-uid";
  const docs = {
    ...settings,
    "users/c1": {role: "customer", bugBucks: 0},
    "transactions/t1": {userId: EX, type: "referral_bonus", amount: 50, balance: 50, referenceId: "r1", createdAt: ts(1)},
    "transactions/t2": {userId: EX, type: "referral_bonus", amount: 50, balance: 100, createdAt: ts(2)},
    "transactions/t3": {userId: EX, type: "task_bonus", amount: 10, balance: 110, createdAt: ts(3)},
    "payout_requests/p1": {userId: EX, amount: 30, status: "pending", method: "bank", accountDetails: "BANK-SECRET"},
    "referrals/r1": {referrerId: EX, referralName: "Lead One", email: "lead@example.test", status: "converted",
      bugBucksEarned: 50, customerName: "Ex Employee", submittedAt: ts(1)},
    "employee_tasks/k1": {employeeId: EX, employeeName: "Ex Employee", customerName: "Client Co", status: "approved",
      bonusAmount: 10, photos: ["https://firebasestorage.googleapis.com/v0/b/x/o/task_photos%2Fk1%2Fp.jpg"], submittedAt: ts(3)},
    "role_requests/q1": {userId: EX, userEmail: "ex@example.test", userName: "Ex Employee", reason: "why",
      requestedRole: "employee", status: "approved"},
    "notifications/n1": {userId: EX, title: "Approved", message: "hi"},
    "notifications/n2": {userId: EX, title: "Paid", message: "hi"},
    "notifications/n3": {userId: "c1", title: "Welcome", message: "hi"},
  };
  const closedDecision = (overrides: Partial<NonNullable<Decisions["closedAccounts"]>[number]> = {}) => decisions({
    closedAccounts: [{
      uid: EX, decisionReference: "Dowell confirmation", legacyBalanceDisposition: "unresolved",
      pendingPayoutDisposition: "unresolved", ...overrides,
    }],
  });

  it("closes the account with a placeholder profile and blocks on each unresolved amount", () => {
    const plan = buildPlan(snapshot(docs), closedDecision());
    assert.deepEqual(codes(plan), ["closed-account-balance-decision-required", "closed-account-payout-decision-required"]);
    assert.equal(written(plan, `users/${EX}`), undefined, "no profile under the real UID");
    const profile = written(plan, `users/${closedAccountPseudonym(EX)}`) as Doc;
    assert.equal(profile.status, "deleted");
    assert.equal(profile.isDeleted, true);
    assert.equal(profile.bugBucks, 0);
    assert.equal(profile.email, undefined);
    assert.equal(profile.role, undefined, "no role, so no claims can ever be issued");
    assert.deepEqual([(profile.closedAccount as Doc).legacyLedgerBalance, (profile.closedAccount as Doc).pendingPayoutAmount], [110, 30]);
    assert.equal(written(plan, `bugbucks_transactions/migration_opening_${EX}`), undefined, "no money moved");
    assert.equal(written(plan, "notifications/n1"), undefined);
    assert.ok(written(plan, "notifications/n3"), "other users' records are untouched");
    assert.deepEqual((plan.summary.closedAccounts as Doc).purgedRecords, 2);
    assert.ok(plan.issues.every((item) => !`${item.path ?? ""} ${item.detail ?? ""}`.includes(EX)));
  });

  it("records approved dispositions, redacts owner data, and keeps financial and third-party records", () => {
    const plan = buildPlan(snapshot(docs), closedDecision({
      legacyBalanceDisposition: "retain-as-obligation", pendingPayoutDisposition: "paid-externally",
      settlementReference: "BANK-REF-1",
    }));
    assert.deepEqual(codes(plan), []);
    assert.deepEqual(codes(plan, "warning"), ["closed-account-obligation-retained"]);
    const payout = written(plan, "payout_requests/p1") as Doc;
    assert.equal(payout.status, "paid_externally");
    assert.equal(payout.settlementReference, "BANK-REF-1");
    assert.equal(payout.accountDetails, undefined);
    assert.equal(payout.amount, 30);
    const referral = written(plan, "referrals/r1") as Doc;
    assert.equal(referral.customerName, undefined);
    assert.equal(referral.referralName, "Lead One");
    assert.equal(referral.isDeleted, true);
    const task = written(plan, "employee_tasks/k1") as Doc;
    assert.equal(task.employeeName, undefined);
    assert.equal(task.photos, undefined);
    assert.equal(task.customerName, "Client Co");
    assert.equal(task.deletedOwnerTaskState, "credited_to_closed_account_balance");
    assert.equal((written(plan, "role_requests/q1") as Doc).userEmail, undefined);
    assert.equal((written(plan, "transactions/t1") as Doc).amount, 50, "ledger retained unchanged");
    const audit = plan.writes.find((write) => write.path.startsWith("audit_logs/migration_account_closure_"));
    assert.equal((audit?.data.records as Doc).notificationsNotMigrated, 2);
  });

  it("cancels the payout and records the write-off without changing amounts or crediting anyone", () => {
    const plan = buildPlan(snapshot(docs), closedDecision({
      legacyBalanceDisposition: "written-off", pendingPayoutDisposition: "cancelled", decisionDate: "2026-10-20",
    }));
    assert.deepEqual(codes(plan), []);
    const pseudonym = closedAccountPseudonym(EX);
    const payout = written(plan, "payout_requests/p1") as Doc;
    assert.deepEqual([payout.status, payout.payable, payout.amount, payout.userId], ["cancelled", false, 30, pseudonym]);
    assert.equal(payout.accountDetails, undefined, "bank details removed once not payable");
    const ledger = ["t1", "t2", "t3"].map((id) => written(plan, `transactions/${id}`) as Doc);
    assert.deepEqual(ledger.map((tx) => [tx.amount, tx.balance, tx.userId]),
      [[50, 50, pseudonym], [50, 100, pseudonym], [10, 110, pseudonym]]);
    const actions = plan.writes.filter((w) => w.path.startsWith("audit_logs/")).map((w) => w.data.action).sort();
    assert.deepEqual(actions, ["ACCOUNT_CLOSED_AT_CLIENT_REQUEST", "BALANCE_WRITTEN_OFF", "MIGRATION_IMPORT", "PAYOUT_CANCELLED"]);
    const writeOff = plan.writes.find((w) => w.data.action === "BALANCE_WRITTEN_OFF")?.data as Doc;
    assert.deepEqual([writeOff.amount, writeOff.decisionDate, writeOff.amountUnit],
      [110, "2026-10-20", "undocumented-legacy-wallet-unit"]);
    assert.deepEqual(writeOff.composition, {referral_bonus: 100, task_bonus: 10});
    const cancelled = plan.writes.find((w) => w.data.action === "PAYOUT_CANCELLED")?.data as Doc;
    assert.equal(cancelled.amountUnit, "undocumented-legacy-wallet-unit");
    assert.ok(!JSON.stringify(writeOff).includes("Bug Bucks"), "the write-off is not labelled as Bug Bucks");
    assert.ok(!plan.writes.some((w) => /bugbucks_transactions|cash_bonus_transactions/.test(w.path)), "no credit created");
    assert.ok(plan.writes.every((w) => !w.path.includes(EX) && !JSON.stringify(w.data).includes(EX)),
      "the real UID appears nowhere in the planned writes");
  });

  it("excludes an unused sign-in without creating a profile, and blocks if it owns records", () => {
    const clean = buildPlan(snapshot(settings), decisions({excludedAccounts: [{uid: "unused-uid", decisionReference: "Dowell"}]}));
    assert.deepEqual(codes(clean), []);
    assert.ok(clean.writes.every((w) => !w.path.startsWith("users/")));
    const owning = buildPlan(snapshot({...settings, "notifications/n1": {userId: "unused-uid"}}),
      decisions({excludedAccounts: [{uid: "unused-uid", decisionReference: "Dowell"}]}));
    assert.ok(codes(owning).includes("excluded-account-has-records"));
  });

  it("requires a settlement reference for an externally paid payout", () => {
    const plan = buildPlan(snapshot(docs), closedDecision({
      legacyBalanceDisposition: "written-off", pendingPayoutDisposition: "paid-externally",
    }));
    assert.deepEqual(codes(plan), ["closed-account-settlement-reference-missing"]);
  });

  it("keeps bank details while a payout is retained as payable", () => {
    const plan = buildPlan(snapshot(docs), closedDecision({
      legacyBalanceDisposition: "retain-as-obligation", pendingPayoutDisposition: "retain-as-obligation",
    }));
    const payout = written(plan, "payout_requests/p1") as Doc;
    assert.equal(payout.status, "pending");
    assert.equal(payout.accountDetails, "BANK-SECRET");
    assert.equal(payout.obligationRetained, true);
  });
});

describe("migration plan: authorised referral reward credit", () => {
  const docs = {
    ...settings,
    "users/c1": {role: "customer", bugBucks: 100, status: "active", needsVerification: false},
    "users/e1": {role: "employee", status: "active", needsVerification: false},
    "referrals/rc": {referrerId: "e1", status: "converted", bugBucksPending: 100, bugBucksEarned: 0, rewardedOnSubmission: false, submittedAt: ts(1)},
    "referrals/rp": {referrerId: "c1", status: "pending", bugBucksPending: 100, bugBucksEarned: 0, rewardedOnSubmission: false, submittedAt: ts(2)},
  };
  const withCredit = (credits: Decisions["referralRewardCredits"]) => decisions({
    balanceMapping: {
      customer: {bugBucks: "bugBucks", cashBonusBalance: "zero"},
      employee: {bugBucks: "zero", cashBonusBalance: "cashBonusBalance"},
    },
    referralRewardCredits: credits,
  });

  it("credits the converted reward exactly once and leaves the pending one uncredited", () => {
    const plan = buildPlan(snapshot(docs), withCredit([{referralId: "rc", amount: 100, decisionReference: "Dowell"}]));
    assert.deepEqual(codes(plan), []);
    const entry = written(plan, "bugbucks_transactions/migration_referral_reward_rc") as Doc;
    assert.deepEqual([entry.userId, entry.amount, entry.balanceBefore, entry.balanceAfter], ["e1", 100, 0, 100]);
    assert.equal((written(plan, "users/e1") as Doc).bugBucks, 100);
    const referral = written(plan, "referrals/rc") as Doc;
    assert.deepEqual([referral.rewardState, referral.bugBucksAwarded, referral.bugBucksPending],
      ["credited-at-migration", 100, 100]);
    assert.equal((written(plan, "referrals/rp") as Doc).rewardState, "legacy");
    assert.deepEqual(plan.summary.pendingReferralRewards, {count: 1, amount: 100});
    assert.deepEqual(plan.summary.referralRewardsCredited, {count: 1, amount: 100});
    assert.equal(plan.summary.finalBugBucksTotal, 200);
    assert.equal(plan.writes.filter((w) => w.path.includes("migration_referral_reward_")).length, 1);
    const again = buildPlan(snapshot(docs), withCredit([{referralId: "rc", amount: 100, decisionReference: "Dowell"}]));
    assert.equal(written(again, "bugbucks_transactions/migration_referral_reward_rc") !== undefined, true);
    assert.equal(again.writes.find((w) => w.path.endsWith("_rc"))?.contentHash,
      plan.writes.find((w) => w.path.endsWith("_rc"))?.contentHash, "deterministic, so a re-run is a no-op");
  });

  it("chains a credit after an existing opening balance", () => {
    const plan = buildPlan(snapshot({...docs, "referrals/rc": {...docs["referrals/rc"], referrerId: "c1"}}),
      withCredit([{referralId: "rc", amount: 100, decisionReference: "Dowell"}]));
    const entry = written(plan, "bugbucks_transactions/migration_referral_reward_rc") as Doc;
    assert.deepEqual([entry.balanceBefore, entry.balanceAfter], [100, 200]);
    assert.equal((written(plan, "users/c1") as Doc).bugBucks, 200);
    assert.equal((written(plan, "bugbucks_transactions/migration_opening_c1") as Doc).balanceAfter, 100);
  });

  it("rejects credits that are not converted, already paid, duplicated, or mismatched", () => {
    const reasons = (extra: Record<string, Doc>, credits: Decisions["referralRewardCredits"]) =>
      buildPlan(snapshot({...docs, ...extra}), withCredit(credits)).issues
        .filter((item) => item.code === "referral-reward-credit-invalid").map((item) => item.detail).join(";");
    assert.match(reasons({}, [{referralId: "rp", amount: 100, decisionReference: "D"}]), /referral-not-converted/);
    assert.match(reasons({"transactions/x": {userId: "e1", type: "referral_bonus", amount: 100, referenceId: "rc", balance: 100, createdAt: ts(1)}},
      [{referralId: "rc", amount: 100, decisionReference: "D"}]), /legacy-ledger-already-paid/);
    assert.match(reasons({}, [{referralId: "rc", amount: 100, decisionReference: "D"}, {referralId: "rc", amount: 100, decisionReference: "D"}]),
      /duplicate-credit-decision/);
    assert.match(reasons({}, [{referralId: "rc", amount: 50, decisionReference: "D"}]), /amount-differs-from-pending-reward/);
  });
});

describe("migration plan: profile status defaults", () => {
  const map = {balanceMapping: {
    customer: {bugBucks: "bugBucks" as const, cashBonusBalance: "zero" as const},
    employee: {bugBucks: "zero" as const, cashBonusBalance: "cashBonusBalance" as const},
    admin: {bugBucks: "zero" as const, cashBonusBalance: "zero" as const},
  }};
  it("activates eligible profiles and resolves a stale request only with an approved request", () => {
    const plan = buildPlan(snapshot({
      ...settings,
      "users/c1": {role: "customer", requestedRole: null},
      "users/a1": {role: "admin"},
      "users/e1": {role: "employee", requestedRole: "employee", needsVerification: false},
      "role_requests/q1": {userId: "e1", requestedRole: "employee", status: "approved"},
      "users/e2": {role: "employee", requestedRole: "employee", needsVerification: false},
      "users/e3": {role: "employee", requestedRole: "employee", needsVerification: false},
      "role_requests/q3a": {userId: "e3", requestedRole: "employee", status: "approved"},
      "role_requests/q3b": {userId: "e3", requestedRole: "employee", status: "pending"},
    }), decisions({...map, profileStatusBackfill: "backfill-rules"}));
    const user = (uid: string) => written(plan, `users/${uid}`) as Doc;
    assert.deepEqual([user("c1").status, user("c1").needsVerification], ["active", false]);
    assert.deepEqual([user("a1").status, user("a1").needsVerification], ["active", false]);
    assert.deepEqual([user("e1").status, user("e1").requestedRole, user("e1").legacyRequestedRole], ["active", undefined, "employee"]);
    assert.equal(user("e2").status, undefined, "no approved request: left for review");
    assert.equal(user("e3").status, undefined, "pending request: left for review");
    assert.deepEqual(codes(plan, "warning"), ["profile-status-review", "profile-status-review"]);
  });

  it("activates nobody by default: status fields stay unset and are reported", () => {
    const plan = buildPlan(snapshot({
      ...settings,
      "users/c1": {role: "customer", requestedRole: null},
      "users/e1": {role: "employee", requestedRole: "employee", needsVerification: false},
      "role_requests/q1": {userId: "e1", requestedRole: "employee", status: "approved"},
    }), decisions(map));
    for (const uid of ["c1", "e1"]) assert.equal((written(plan, `users/${uid}`) as Doc).status, undefined);
    assert.equal((written(plan, "users/e1") as Doc).requestedRole, "employee");
    assert.deepEqual(codes(plan), []);
    assert.deepEqual(codes(plan, "info"), ["profile-status-left-unset", "profile-status-left-unset"]);
    assert.equal((plan.summary.profileDefaults as Doc).leftUnset, 2);
  });

  it("keeps the original backfill rules when no role-request context is given", () => {
    assert.deepEqual(profileDefaults({role: "customer"}), {kind: "update", update: {status: "active", needsVerification: false}});
    assert.deepEqual(profileDefaults({role: "employee", requestedRole: "employee"}), {kind: "review", reason: "missing-status"});
    assert.deepEqual(profileDefaults({status: "pending"}), {kind: "update", update: {needsVerification: true}});
  });

  it("closes a zero-balance account with a placeholder and no active profile", () => {
    const plan = buildPlan(snapshot({
      ...settings,
      "users/ath": {role: "athlete", walletBalance: 0, fullName: "Ath Lete", email: "ath@example.test", requestedRole: "athlete"},
      "role_requests/qa": {userId: "ath", requestedRole: "athlete", status: "approved", userEmail: "ath@example.test"},
    }), decisions({...map, closedAccounts: [{uid: "ath", decisionReference: "Dowell", legacyBalanceDisposition: "none",
      pendingPayoutDisposition: "none", closureReason: "legacy-athlete-account-closed-at-client-request"}]}));
    assert.deepEqual(codes(plan), []);
    assert.equal(written(plan, "users/ath"), undefined);
    const placeholder = written(plan, `users/${closedAccountPseudonym("ath")}`) as Doc;
    assert.deepEqual([placeholder.status, placeholder.deletionReason, placeholder.email, placeholder.role],
      ["deleted", "legacy-athlete-account-closed-at-client-request", undefined, undefined]);
    assert.equal((written(plan, "role_requests/qa") as Doc).userEmail, undefined);
    assert.ok(plan.writes.every((w) => !JSON.stringify(w.data).includes("Ath Lete")));
  });
});

describe("migration claims policy", () => {
  it("skips closed profiles and approves only the provisioned client admin", () => {
    assert.equal(isClosedProfile({status: "deleted"}), true);
    assert.equal(isClosedProfile({status: "active", isDeleted: false}), false);
    const profiles = [
      {id: "client", email: "Client.Admin@Example.test", provisionedClientAdmin: true},
      {id: "imposter", email: "client.admin@example.test"},
    ];
    const clientAdmin = {email: "client.admin@example.test", approved: true};
    assert.deepEqual([...approvedAdminSet({approvedAdminUids: [], clientAdmin}, profiles)], ["client"]);
    assert.deepEqual([...approvedAdminSet({approvedAdminUids: [], clientAdmin: {...clientAdmin, approved: false}}, profiles)], []);
  });

  const approved = new Set(["admin-ok"]);
  it("maps only supported roles and approved admins", () => {
    assert.deepEqual(claimDecision("c", "customer", {}, approved, "active"),
      {kind: "set", claims: {role: "customer", admin: false, employee: false}});
    assert.deepEqual(claimDecision("a", "admin", {}, approved, "active"), {kind: "held", reason: "admin-not-approved"});
    assert.equal(claimDecision("admin-ok", "admin", {}, approved, "active").kind, "set");
    assert.deepEqual(claimDecision("x", "nil_athlete", {}, approved, "active"), {kind: "held", reason: "unsupported-role:nil_athlete"});
    assert.deepEqual(claimDecision("x", undefined, {}, approved, "active"), {kind: "held", reason: "missing-role"});
  });

  it("issues no claims to profiles that are not active, and never admin to unapproved accounts", () => {
    const approved = new Set(["admin-ok"]);
    assert.deepEqual(claimDecision("e", "employee", {}, approved, undefined), {kind: "held", reason: "status-not-active"});
    assert.deepEqual(claimDecision("c", "customer", {}, approved, "pending"), {kind: "held", reason: "status-not-active"});
    assert.deepEqual(claimDecision("a", "admin", {}, approved, undefined), {kind: "held", reason: "admin-not-approved"});
    assert.deepEqual(claimDecision("admin-ok", "admin", {}, approved, undefined), {kind: "held", reason: "status-not-active"});
  });
});
