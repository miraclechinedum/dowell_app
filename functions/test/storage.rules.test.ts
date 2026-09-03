import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {deleteObject, getBytes, ref, updateMetadata, uploadBytes} from "firebase/storage";
import {after, before, describe, it} from "mocha";

let environment: RulesTestEnvironment;
const ownedPath = "task_evidence/employee/request_1234567890/photo_0.jpg";

describe("Storage evidence authorization rules", () => {
  before(async () => {
    environment = await initializeTestEnvironment({
      projectId: "demo-dowell",
      storage: {
        rules: readFileSync(resolve(process.cwd(), "..", "storage.rules"), "utf8"),
      },
    });
  });

  after(async () => environment?.cleanup());

  it("allows an employee to upload only inside their own path", async () => {
    const storage = environment.authenticatedContext("employee", {employee: true}).storage();
    const bytes = new Uint8Array([0xff, 0xd8, 0xff]);
    await assertSucceeds(uploadBytes(ref(storage, ownedPath), bytes, {contentType: "image/jpeg"}));
    await assertFails(uploadBytes(
      ref(storage, "task_evidence/another/request_1234567890/photo_0.jpg"),
      bytes,
      {contentType: "image/jpeg"},
    ));
  });

  it("denies unauthenticated and cross-employee evidence reads", async () => {
    const owner = environment.authenticatedContext("employee", {employee: true}).storage();
    const other = environment.authenticatedContext("other", {employee: true}).storage();
    const anonymous = environment.unauthenticatedContext().storage();
    await assertSucceeds(getBytes(ref(owner, ownedPath)));
    await assertFails(getBytes(ref(other, ownedPath)));
    await assertFails(getBytes(ref(anonymous, ownedPath)));
  });

  it("denies customers and allows claimed-admin reads", async () => {
    const customer = environment.authenticatedContext("customer").storage();
    const admin = environment.authenticatedContext("admin", {admin: true}).storage();
    await assertFails(getBytes(ref(customer, ownedPath)));
    await assertSucceeds(getBytes(ref(admin, ownedPath)));
  });

  it("enforces size, MIME type, and physical-delete restrictions", async () => {
    const storage = environment.authenticatedContext("employee", {employee: true}).storage();
    await assertFails(uploadBytes(
      ref(storage, "task_evidence/employee/request_1234567890/file.txt"),
      new Uint8Array([1]), {contentType: "text/plain"},
    ));
    await assertFails(uploadBytes(
      ref(storage, "task_evidence/employee/request_1234567890/large.jpg"),
      new Uint8Array(10 * 1024 * 1024 + 1), {contentType: "image/jpeg"},
    ));
    await assertFails(deleteObject(ref(storage, ownedPath)));
  });

  it("prevents employee access and mutation after trusted archival", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await updateMetadata(ref(context.storage(), ownedPath), {customMetadata: {archived: "true"}});
    });
    const employee = environment.authenticatedContext("employee", {employee: true}).storage();
    const admin = environment.authenticatedContext("admin", {admin: true}).storage();
    await assertFails(getBytes(ref(employee, ownedPath)));
    await assertFails(updateMetadata(ref(employee, ownedPath), {contentType: "image/jpeg"}));
    await assertSucceeds(getBytes(ref(admin, ownedPath)));
  });
});
