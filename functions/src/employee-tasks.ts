import {createHash} from "node:crypto";
import {FieldValue, Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {ReferralAuth} from "./referrals.js";

const FIELDS = new Set([
  "requestId", "title", "description", "customerName", "customerEmail",
  "customerPhone", "customerAddress", "notes", "imageUrls", "imagePaths", "amount",
  "type", "category", "priority",
]);

interface TaskInput {
  requestId: string; title: string; description: string; customerName: string;
  customerEmail: string; customerPhone: string; customerAddress: string;
  notes: string; imageUrls: string[]; imagePaths: string[]; amount: number; type: string;
  category: string; priority: string;
}

function text(value: unknown, field: string, max: number, required = true): string {
  if (typeof value !== "string") throw new HttpsError("invalid-argument", `${field} is invalid.`);
  const result = value.trim();
  if ((required && !result) || result.length > max) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return result;
}

export function validateEmployeeTask(data: unknown): TaskInput {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "Task details are invalid.");
  }
  const raw = data as Record<string, unknown>;
  if (Object.keys(raw).some((key) => !FIELDS.has(key))) {
    throw new HttpsError("invalid-argument", "Task details contain unsupported fields.");
  }
  const requestId = text(raw.requestId, "requestId", 128);
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(requestId)) {
    throw new HttpsError("invalid-argument", "requestId is invalid.");
  }
  const email = text(raw.customerEmail, "customerEmail", 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "customerEmail is invalid.");
  }
  if (!Array.isArray(raw.imageUrls) || raw.imageUrls.length < 1 || raw.imageUrls.length > 10 ||
      raw.imageUrls.some((url) => typeof url !== "string" || url.length > 2048 ||
        !url.startsWith("https://"))) {
    throw new HttpsError("invalid-argument", "imageUrls is invalid.");
  }
  if (!Array.isArray(raw.imagePaths) || raw.imagePaths.length !== raw.imageUrls.length ||
      raw.imagePaths.some((path) => typeof path !== "string" || path.length > 1024 ||
        !path.startsWith("task_evidence/"))) {
    throw new HttpsError("invalid-argument", "imagePaths is invalid.");
  }
  if (typeof raw.amount !== "number" || !Number.isFinite(raw.amount) ||
      raw.amount < 0 || raw.amount > 1000000) {
    throw new HttpsError("invalid-argument", "amount is invalid.");
  }
  const priority = text(raw.priority, "priority", 16);
  if (!["low", "medium", "high"].includes(priority)) {
    throw new HttpsError("invalid-argument", "priority is invalid.");
  }
  return {
    requestId,
    title: text(raw.title, "title", 160),
    description: text(raw.description, "description", 4000),
    customerName: text(raw.customerName, "customerName", 120),
    customerEmail: email,
    customerPhone: text(raw.customerPhone, "customerPhone", 40),
    customerAddress: text(raw.customerAddress ?? "", "customerAddress", 500, false),
    notes: text(raw.notes ?? "", "notes", 2000, false),
    imageUrls: raw.imageUrls as string[],
    imagePaths: raw.imagePaths as string[],
    amount: raw.amount,
    type: text(raw.type, "type", 80),
    category: text(raw.category, "category", 80),
    priority,
  };
}

function hash(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function taskPayloadHash(input: TaskInput): string {
  return hash(JSON.stringify([
    input.title.toLowerCase(), input.description.toLowerCase(),
    input.customerName.toLowerCase(), input.customerEmail,
    input.customerPhone.replace(/\D/g, ""), input.customerAddress.toLowerCase(),
    input.notes.toLowerCase(), [...input.imagePaths].sort(), input.amount,
    input.type, input.category, input.priority,
  ]));
}

function counter(value: unknown, field: string): number {
  if (value == null) return 0;
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    console.error("Task submission blocked by malformed counter", {field});
    throw new HttpsError("failed-precondition", "Employee counters require review.");
  }
  return value;
}

export async function submitEmployeeTaskForUser(
  db: Firestore, auth: ReferralAuth | undefined, data: unknown,
): Promise<{success: true; taskId: string}> {
  if (!auth) throw new HttpsError("unauthenticated", "Authentication is required.");
  if (auth.token.employee !== true || auth.token.admin === true) {
    throw new HttpsError("permission-denied", "Employee authorization is required.");
  }
  const input = validateEmployeeTask(data);
  const evidencePrefix = `task_evidence/${auth.uid}/${input.requestId}/`;
  if (input.imagePaths.some((path) => !path.startsWith(evidencePrefix))) {
    throw new HttpsError("invalid-argument", "Evidence path is invalid.");
  }
  const payloadHash = taskPayloadHash(input);
  const taskId = hash(`${auth.uid}:${input.requestId}`);
  const taskRef = db.collection("employee_tasks").doc(taskId);
  const userRef = db.collection("users").doc(auth.uid);

  return db.runTransaction(async (transaction) => {
    const [task, user] = await Promise.all([
      transaction.get(taskRef), transaction.get(userRef),
    ]);
    if (task.exists) {
      if (task.get("employeeId") === auth.uid && task.get("requestId") === input.requestId &&
          task.get("payloadHash") === payloadHash) {
        return {success: true, taskId};
      }
      throw new HttpsError("already-exists", "Request ID is bound to another task.");
    }
    if (!user.exists || user.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "Employee account is not active.");
    }
    const now = FieldValue.serverTimestamp();
    transaction.create(taskRef, {
      id: taskId,
      requestId: input.requestId,
      payloadHash,
      employeeId: auth.uid,
      employeeName: user.get("displayName") ?? user.get("name") ?? "Employee",
      employeeEmail: typeof auth.token.email === "string" ? auth.token.email : user.get("email") ?? "",
      title: input.title,
      description: input.description,
      customerName: input.customerName,
      customerEmail: input.customerEmail,
      customerPhone: input.customerPhone,
      customerAddress: input.customerAddress,
      notes: input.notes,
      images: input.imageUrls,
      imageUrls: input.imageUrls,
      imagePaths: input.imagePaths,
      amount: input.amount,
      amountAuthority: "employee_estimate_only",
      type: input.type,
      category: input.category,
      priority: input.priority,
      status: "pending",
      isDeleted: false,
      isPaid: false,
      createdAt: now,
      updatedAt: now,
      submittedAt: now,
    });
    transaction.update(userRef, {
      pendingTasks: counter(user.get("pendingTasks"), "pendingTasks") + 1,
      totalTasks: counter(user.get("totalTasks"), "totalTasks") + 1,
      updatedAt: now,
    });
    return {success: true, taskId};
  });
}
