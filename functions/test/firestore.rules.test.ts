import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {deleteDoc, deleteField, doc, getDoc, serverTimestamp, setDoc, updateDoc} from "firebase/firestore";
import {after, afterEach, before, describe, it} from "mocha";

const projectId = "demo-dowell";
let environment: RulesTestEnvironment;

const customerProfile = {
  email: "customer@example.com",
  displayName: "Customer",
  role: "customer",
  status: "active",
  needsVerification: false,
  bugBucks: 0,
  cashBonusBalance: 0,
  totalReferrals: 0,
  convertedReferrals: 0,
  totalTasks: 0,
};

async function seedUser(uid: string, overrides: Record<string, unknown> = {}) {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users", uid), {
      ...customerProfile,
      ...overrides,
    });
  });
}

describe("Firestore authorization rules", () => {
  before(async () => {
    environment = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: readFileSync(
          resolve(process.cwd(), "..", "firestore.rules"),
          "utf8",
        ),
      },
    });
  });

  afterEach(async () => environment.clearFirestore());
  after(async () => environment?.cleanup());

  it("prevents a customer changing their role to admin", async () => {
    await seedUser("alice");
    const db = environment.authenticatedContext("alice").firestore();
    await assertFails(updateDoc(doc(db, "users", "alice"), {role: "admin"}));
  });

  it("prevents a new profile choosing an admin role", async () => {
    const db = environment.authenticatedContext("new-user").firestore();
    await assertFails(
      setDoc(doc(db, "users", "new-user"), {
        ...customerProfile,
        role: "admin",
      }),
    );
  });

  it("allows only the explicit safe customer profile shape", async () => {
    const db = environment.authenticatedContext("new-user").firestore();
    const safe = {
      email: "new@example.com", role: "customer", status: "active",
      needsVerification: false, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(db, "users", "new-user"), safe));
    await assertFails(setDoc(doc(db, "users", "new-user"), {
      ...safe, cashBalance: 1000,
    }));
  });

  it("prevents a customer changing Bug Bucks", async () => {
    await seedUser("alice");
    const db = environment.authenticatedContext("alice").firestore();
    await assertFails(updateDoc(doc(db, "users", "alice"), {bugBucks: 100}));
  });

  it("prevents a customer changing cashBonusBalance", async () => {
    await seedUser("alice");
    const db = environment.authenticatedContext("alice").firestore();
    await assertFails(updateDoc(doc(db, "users", "alice"), {cashBonusBalance: 25}));
  });

  it("prevents a customer changing protected counters", async () => {
    await seedUser("alice");
    const db = environment.authenticatedContext("alice").firestore();
    for (const field of ["totalReferrals", "convertedReferrals", "totalTasks"]) {
      await assertFails(updateDoc(doc(db, "users", "alice"), {[field]: 1}));
    }
  });

  it("prevents a customer fabricating approval fields", async () => {
    await seedUser("alice");
    const db = environment.authenticatedContext("alice").firestore();
    await assertFails(
      updateDoc(doc(db, "users", "alice"), {
        approvedBy: "alice",
        approvalNotes: "self approved",
      }),
    );
  });

  it("prevents a customer creating Bug Bucks transactions", async () => {
    await seedUser("alice");
    const db = environment.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(db, "bugbucks_transactions", "fake"), {
        userId: "alice",
        amount: 100000,
        type: "referral",
      }),
    );
  });

  it("prevents a customer creating a referral directly", async () => {
    const db = environment.authenticatedContext("alice").firestore();
    await assertFails(setDoc(doc(db, "referrals", "forged"), {
      customerId: "alice", status: "pending", bugBucksAwarded: 100,
    }));
  });

  it("prevents direct employee task creation", async () => {
    const db = environment
      .authenticatedContext("employee", {employee: true, role: "employee"})
      .firestore();
    await assertFails(setDoc(doc(db, "employee_tasks", "fake"), {
      employeeId: "employee", status: "pending",
    }));
  });

  it("allows a customer to read only their own referral", async () => {
    await seedUser("alice");
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "referrals", "alice-referral"), {
        customerId: "alice", status: "pending",
      });
      await setDoc(doc(context.firestore(), "referrals", "bob-referral"), {
        customerId: "bob", status: "pending",
      });
    });
    const db = environment.authenticatedContext("alice").firestore();
    await assertSucceeds(getDoc(doc(db, "referrals", "alice-referral")));
    await assertFails(getDoc(doc(db, "referrals", "bob-referral")));
  });

  it("allows a claimed admin to manage referrals", async () => {
    const db = environment
      .authenticatedContext("admin", {admin: true, role: "admin"})
      .firestore();
    const ref = doc(db, "referrals", "admin-created");
    await assertSucceeds(setDoc(ref, {customerId: "alice", status: "pending"}));
    await assertSucceeds(updateDoc(ref, {status: "converted", adminNotes: "Approved"}));
  });

  it("prevents owners deleting profiles, referrals, and financial ledgers", async () => {
    await seedUser("alice");
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "referrals", "owned"), {customerId: "alice"});
      await setDoc(doc(context.firestore(), "bugbucks_transactions", "owned"), {userId: "alice"});
    });
    const db = environment.authenticatedContext("alice").firestore();
    await assertFails(deleteDoc(doc(db, "users", "alice")));
    await assertFails(deleteDoc(doc(db, "referrals", "owned")));
    await assertFails(deleteDoc(doc(db, "bugbucks_transactions", "owned")));
  });

  it("prevents physical deletion of tasks and all admin-managed records", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "employee_tasks", "task"), {employeeId: "employee"});
      await setDoc(doc(context.firestore(), "referrals", "referral"), {customerId: "alice"});
      await setDoc(doc(context.firestore(), "users", "alice"), customerProfile);
    });
    const employee = environment.authenticatedContext("employee", {employee: true}).firestore();
    const admin = environment.authenticatedContext("admin", {admin: true}).firestore();
    await assertFails(deleteDoc(doc(employee, "employee_tasks", "task")));
    await assertFails(deleteDoc(doc(admin, "employee_tasks", "task")));
    await assertFails(deleteDoc(doc(admin, "referrals", "referral")));
    await assertFails(deleteDoc(doc(admin, "users", "alice")));
  });

  it("prevents clients and admins spoofing trusted deletion metadata", async () => {
    await seedUser("alice");
    const customer = environment.authenticatedContext("alice").firestore();
    const admin = environment.authenticatedContext("admin", {admin: true}).firestore();
    await assertFails(updateDoc(doc(customer, "users", "alice"), {
      isDeleted: true, deletedBy: "alice", deletedSource: "self",
    }));
    await assertFails(updateDoc(doc(admin, "users", "alice"), {
      isDeleted: true, deletedBy: "admin", deletedSource: "admin",
    }));
  });

  it("prevents a deleted user resuming ordinary mutations", async () => {
    await seedUser("alice", {status: "deleted", isDeleted: true});
    const db = environment.authenticatedContext("alice").firestore();
    await assertFails(updateDoc(doc(db, "users", "alice"), {displayName: "Active again"}));
  });

  it("keeps audit history immutable even for ordinary admins", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "audit_logs", "event"), {action: "DELETE"});
    });
    const customer = environment.authenticatedContext("alice").firestore();
    const admin = environment.authenticatedContext("admin", {admin: true}).firestore();
    await assertFails(setDoc(doc(customer, "audit_logs", "forged"), {action: "FORGED"}));
    await assertFails(updateDoc(doc(customer, "audit_logs", "event"), {action: "FORGED"}));
    await assertFails(deleteDoc(doc(customer, "audit_logs", "event")));
    await assertFails(updateDoc(doc(admin, "audit_logs", "event"), {action: "CHANGED"}));
    await assertFails(deleteDoc(doc(admin, "audit_logs", "event")));
  });

  it("fails malformed legacy role transitions without allowing writes", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", "legacy"), {email: "legacy@example.com"});
    });
    const db = environment.authenticatedContext("legacy").firestore();
    await assertFails(updateDoc(doc(db, "users", "legacy"), {
      status: "pending", needsVerification: true, requestedRole: "employee",
    }));
    await assertFails(updateDoc(doc(db, "users", "legacy"), {pendingTasks: 99}));
  });

  it("lets claimed admins create notifications but not ledger entries", async () => {
    const db = environment.authenticatedContext("admin", {admin: true}).firestore();
    // Ledgers are written only by trusted Functions (admin-finance.ts).
    await assertFails(setDoc(doc(db, "cash_bonus_transactions", "bonus"), {
      userId: "employee", amount: 25,
    }));
    await assertFails(setDoc(doc(db, "bugbucks_transactions", "credit"), {
      userId: "alice", type: "admin_adjustment", amount: 500,
    }));
    await assertSucceeds(setDoc(doc(db, "notifications", "notice"), {
      userId: "alice", title: "Notice",
    }));
  });

  it("prevents admins changing balances directly while allowing status and profile edits", async () => {
    await seedUser("alice", {bugBucks: 100, cashBonusBalance: 5});
    const admin = environment.authenticatedContext("admin", {admin: true}).firestore();
    await assertFails(updateDoc(doc(admin, "users", "alice"), {bugBucks: 1000}));
    await assertFails(updateDoc(doc(admin, "users", "alice"), {cashBonusBalance: 500}));
    await assertFails(updateDoc(doc(admin, "users", "alice"), {walletBalance: 50}));
    await assertSucceeds(updateDoc(doc(admin, "users", "alice"), {status: "inactive", statusReason: "Review"}));
    await assertSucceeds(updateDoc(doc(admin, "users", "alice"), {displayName: "Alice A."}));
    await assertFails(setDoc(doc(admin, "users", "minted"), {role: "customer", status: "active", bugBucks: 50}));
  });

  it("does not let a Firestore-only admin role change balances", async () => {
    await seedUser("legacy-admin", {role: "admin"});
    await seedUser("alice", {bugBucks: 100});
    const db = environment.authenticatedContext("legacy-admin").firestore();
    await assertFails(updateDoc(doc(db, "users", "alice"), {bugBucks: 999}));
    await assertFails(setDoc(doc(db, "bugbucks_transactions", "x"), {userId: "alice", amount: 1}));
  });

  it("prevents client-side task approval or bonus changes", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "employee_tasks", "task"), {
        employeeId: "employee", status: "pending", isDeleted: false,
      });
    });
    const admin = environment.authenticatedContext("admin", {admin: true}).firestore();
    await assertFails(updateDoc(doc(admin, "employee_tasks", "task"), {status: "approved"}));
    await assertFails(updateDoc(doc(admin, "employee_tasks", "task"), {cashBonusAwarded: 25}));
    await assertFails(updateDoc(doc(admin, "employee_tasks", "task"), {paidOut: true}));
    await assertFails(updateDoc(doc(admin, "employee_tasks", "task"), {employeeId: "someone-else"}));
    await assertSucceeds(updateDoc(doc(admin, "employee_tasks", "task"), {adminNotes: "Checked photos"}));
  });

  it("prevents admins changing derived task and referral counters", async () => {
    await seedUser("emp", {role: "employee", pendingTasks: 2, totalTasks: 5});
    const admin = environment.authenticatedContext("admin", {admin: true}).firestore();
    for (const [field, value] of [["pendingTasks", 0], ["totalTasks", 99], ["approvedTasks", 3],
      ["totalReferrals", 50], ["convertedReferrals", 10]] as const) {
      await assertFails(updateDoc(doc(admin, "users", "emp"), {[field]: value}));
    }
    await assertFails(setDoc(doc(admin, "users", "seeded"), {role: "employee", status: "active", totalTasks: 7}));
    await assertSucceeds(setDoc(doc(admin, "users", "fresh"), {role: "customer", status: "active", totalTasks: 0}));
    const legacyAdmin = environment.authenticatedContext("legacy-admin").firestore();
    await seedUser("legacy-admin", {role: "admin"});
    await assertFails(updateDoc(doc(legacyAdmin, "users", "emp"), {pendingTasks: 0}));
  });

  it("denies every client write to legacy employee_cashouts while keeping reads", async () => {
    await seedUser("emp", {role: "employee"});
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "employee_cashouts", "c1"), {
        employeeId: "emp", amount: 30, status: "pending", isDeleted: false,
      });
    });
    const admin = environment.authenticatedContext("admin", {admin: true}).firestore();
    const owner = environment.authenticatedContext("emp").firestore();
    const other = environment.authenticatedContext("someone").firestore();
    await assertFails(setDoc(doc(admin, "employee_cashouts", "c2"), {employeeId: "emp", amount: 10, status: "pending"}));
    await assertFails(setDoc(doc(owner, "employee_cashouts", "c3"), {employeeId: "emp", amount: 10, status: "pending"}));
    for (const status of ["approved", "rejected", "cancelled", "paid"]) {
      await assertFails(updateDoc(doc(admin, "employee_cashouts", "c1"), {status}));
      await assertFails(updateDoc(doc(owner, "employee_cashouts", "c1"), {status}));
    }
    await assertFails(updateDoc(doc(admin, "employee_cashouts", "c1"), {amount: 300}));
    await assertFails(deleteDoc(doc(admin, "employee_cashouts", "c1")));
    await assertSucceeds(getDoc(doc(owner, "employee_cashouts", "c1")));
    await assertSucceeds(getDoc(doc(admin, "employee_cashouts", "c1")));
    await assertFails(getDoc(doc(other, "employee_cashouts", "c1")));
  });

  it("only lets admins save a valid employee task bonus, including the boundaries", async () => {
    const admin = environment.authenticatedContext("admin", {admin: true}).firestore();
    const settings = doc(admin, "app_settings", "reward_settings");
    // Same shape as the Admin Settings screen: merge-save of all reward fields.
    const save = (bonus: unknown) => setDoc(settings, {
      referral_bug_bucks: 100, converted_referral_bonus: 50, employee_task_bug_bucks: 50,
      employee_cash_bonus: bonus, updated_at: serverTimestamp(), updated_by: "admin",
    }, {merge: true});
    for (const valid of [0.01, 1000, 25, 12.5, 999.99]) await assertSucceeds(save(valid));
    for (const invalid of [0, -1, 1000.01, 0.001, 2.345, "25", Infinity, null]) await assertFails(save(invalid));
    // A later partial update keeps the stored valid bonus and is allowed.
    await assertSucceeds(updateDoc(settings, {referral_bug_bucks: 120}));
    await assertFails(updateDoc(settings, {employee_cash_bonus: deleteField()}));
    await assertFails(deleteDoc(settings));
    // A brand-new document without the bonus is refused.
    await environment.withSecurityRulesDisabled(async (context) => {
      await deleteDoc(doc(context.firestore(), "app_settings", "reward_settings"));
    });
    await assertFails(setDoc(settings, {referral_bug_bucks: 100}));
    // Other settings documents keep their existing admin behaviour.
    await assertSucceeds(setDoc(doc(admin, "app_settings", "global"), {updated_by: "admin"}));
    await assertSucceeds(deleteDoc(doc(admin, "app_settings", "global")));
  });

  it("denies non-admins and Firestore-only admins writing reward settings", async () => {
    await seedUser("legacy-admin", {role: "admin"});
    for (const uid of ["alice", "legacy-admin"]) {
      const db = environment.authenticatedContext(uid).firestore();
      await assertFails(setDoc(doc(db, "app_settings", "reward_settings"), {employee_cash_bonus: 25}));
    }
    await assertFails(setDoc(doc(environment.unauthenticatedContext().firestore(), "app_settings", "reward_settings"),
      {employee_cash_bonus: 25}));
  });

  it("lets owners only mark their own notifications read or dismissed", async () => {
    await seedUser("alice");
    await seedUser("bob");
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "notifications", "n1"), {
        userId: "alice", title: "Task approved", message: "Well done", read: false, isDeleted: false,
      });
    });
    const alice = environment.authenticatedContext("alice").firestore();
    await assertSucceeds(updateDoc(doc(alice, "notifications", "n1"), {read: true, readAt: serverTimestamp()}));
    await assertSucceeds(updateDoc(doc(alice, "notifications", "n1"), {dismissed: true, dismissedAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(alice, "notifications", "n1"), {userId: "bob"}));
    await assertFails(updateDoc(doc(alice, "notifications", "n1"), {title: "Edited"}));
    await assertFails(updateDoc(doc(alice, "notifications", "n1"), {read: "yes"}));
    await assertFails(updateDoc(doc(alice, "notifications", "n1"), {readAt: "today"}));
    await assertFails(updateDoc(doc(alice, "notifications", "n1"), {read: true, type: "payout"}));
    const bob = environment.authenticatedContext("bob").firestore();
    await assertFails(updateDoc(doc(bob, "notifications", "n1"), {read: true}));
    const admin = environment.authenticatedContext("admin", {admin: true}).firestore();
    await assertFails(updateDoc(doc(admin, "notifications", "n1"), {userId: "bob"}));
    await assertSucceeds(updateDoc(doc(admin, "notifications", "n1"), {title: "Task approved (updated)"}));
  });

  it("allows legitimate profile edits", async () => {
    await seedUser("alice");
    const db = environment.authenticatedContext("alice").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "users", "alice"), {
        displayName: "Alice Customer",
        phone: "5551234567",
      }),
    );
  });

  it("allows the constrained employee role-request transition", async () => {
    await seedUser("alice");
    const db = environment.authenticatedContext("alice").firestore();
    await assertSucceeds(
      setDoc(doc(db, "role_requests", "request-1"), {
        userId: "alice",
        requestedRole: "employee",
        status: "pending",
        isDeleted: false,
        reviewedAt: null,
        reviewedBy: null,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(db, "users", "alice"), {
        needsVerification: true,
        requestedRole: "employee",
        status: "pending",
      }),
    );
  });

  it("prevents a deleted profile creating a role request with a stale token", async () => {
    await seedUser("deleted", {status: "deleted", isDeleted: true});
    const db = environment.authenticatedContext("deleted").firestore();
    await assertFails(setDoc(doc(db, "role_requests", "deleted-request"), {
      userId: "deleted", requestedRole: "employee", status: "pending",
      isDeleted: false, reviewedAt: null, reviewedBy: null,
    }));
  });

  it("does not allow one customer to update another customer", async () => {
    await seedUser("alice");
    await seedUser("bob");
    const db = environment.authenticatedContext("alice").firestore();
    await assertFails(updateDoc(doc(db, "users", "bob"), {displayName: "Owned"}));
  });

  it("does not grant admin authority from a Firestore profile role", async () => {
    await seedUser("alice", {role: "admin"});
    const db = environment.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(db, "audit_logs", "forged"), {action: "FORGED"}),
    );
  });

  it("allows an admin custom claim to perform privileged writes", async () => {
    const db = environment
      .authenticatedContext("real-admin", {admin: true, role: "admin"})
      .firestore();
    await assertSucceeds(
      setDoc(doc(db, "audit_logs", "valid"), {action: "ROLE_CHANGE"}),
    );
  });
});
