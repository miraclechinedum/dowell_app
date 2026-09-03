import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc} from "firebase/firestore";
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

  it("preserves claimed-admin financial and notification writes", async () => {
    const db = environment.authenticatedContext("admin", {admin: true}).firestore();
    await assertSucceeds(setDoc(doc(db, "cash_bonus_transactions", "bonus"), {
      userId: "employee", amount: 25,
    }));
    await assertSucceeds(setDoc(doc(db, "notifications", "notice"), {
      userId: "alice", title: "Notice",
    }));
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
