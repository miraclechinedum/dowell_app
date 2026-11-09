import {DocumentReference, Firestore, GeoPoint, Timestamp} from "firebase-admin/firestore";
import {Encoded} from "./common.js";

export function encodeValue(value: unknown): Encoded {
  if (value === null || typeof value === "boolean" || typeof value === "string") return value;
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("Non-finite number cannot be snapshotted.");
    return value;
  }
  if (value instanceof Timestamp) {
    return {__type: "timestamp", seconds: value.seconds, nanoseconds: value.nanoseconds};
  }
  if (value instanceof GeoPoint) {
    return {__type: "geopoint", latitude: value.latitude, longitude: value.longitude};
  }
  if (value instanceof DocumentReference) return {__type: "reference", path: value.path};
  if (Buffer.isBuffer(value) || value instanceof Uint8Array) {
    return {__type: "bytes", base64: Buffer.from(value).toString("base64")};
  }
  if (Array.isArray(value)) return value.map(encodeValue);
  if (typeof value === "object") {
    const out: {[key: string]: Encoded} = {};
    for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
      if (key === "__type") throw new Error("Field name __type is reserved by the snapshot encoder.");
      out[key] = encodeValue(item);
    }
    return out;
  }
  throw new Error(`Unsupported Firestore value type: ${typeof value}`);
}

export function decodeValue(value: Encoded, db: Firestore): unknown {
  if (Array.isArray(value)) return value.map((item) => decodeValue(item, db));
  if (value != null && typeof value === "object") {
    switch (value.__type) {
    case "timestamp":
      return new Timestamp(value.seconds as number, value.nanoseconds as number);
    case "geopoint":
      return new GeoPoint(value.latitude as number, value.longitude as number);
    case "reference":
      return db.doc(value.path as string);
    case "bytes":
      return Buffer.from(value.base64 as string, "base64");
    default: {
      const out: Record<string, unknown> = {};
      for (const [key, item] of Object.entries(value)) out[key] = decodeValue(item, db);
      return out;
    }
    }
  }
  return value;
}
