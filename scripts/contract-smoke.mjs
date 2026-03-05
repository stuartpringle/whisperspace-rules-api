#!/usr/bin/env node
import process from "node:process";

const DEFAULT_BASE_URL = "https://rules-api.whisperspace.com";
const baseUrl = (process.env.WS_RULES_API_BASE || DEFAULT_BASE_URL).replace(/\/+$/, "");
const roomId = process.env.WS_SMOKE_ROOM_ID || "contract-smoke-room";
const instanceId = process.env.WS_SMOKE_INSTANCE_ID || "contract-smoke-instance";
const obrUrl = `${baseUrl}/character-api/obr-instance/${encodeURIComponent(
  instanceId
)}?roomId=${encodeURIComponent(roomId)}`;

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function expect(condition, message) {
  if (!condition) throw new Error(message);
}

async function getJson(url, expectedStatus) {
  const response = await fetch(url, { method: "GET" });
  const text = await response.text();
  let payload = null;
  try {
    payload = JSON.parse(text);
  } catch (error) {
    throw new Error(`${url} returned non-JSON body (status ${response.status})`);
  }
  expect(
    response.status === expectedStatus,
    `${url} returned ${response.status}, expected ${expectedStatus}`
  );
  return payload;
}

async function run() {
  const checks = [];

  const meta = await getJson(`${baseUrl}/rules-api/latest/meta.json`, 200);
  expect(typeof meta.version === "string" && meta.version.length > 0, "meta.version missing");
  expect(
    typeof meta.generatedAt === "string" && meta.generatedAt.length > 0,
    "meta.generatedAt missing"
  );
  expect(isObject(meta.files), "meta.files missing");
  checks.push("rules meta");

  const schemas = await getJson(`${baseUrl}/rules-api/calc/schemas/index.json`, 200);
  expect(isObject(schemas), "calc schemas payload must be object");
  expect(
    isObject(schemas.endpoints),
    "calc schemas index missing endpoints map"
  );
  expect(
    typeof schemas.endpoints["/derive-attributes"] === "string",
    "calc schemas index missing /derive-attributes endpoint"
  );
  checks.push("calc schemas");

  const characterSchema = await getJson(`${baseUrl}/character-api/schema.json`, 200);
  expect(
    isObject(characterSchema) && (typeof characterSchema.$schema === "string" || isObject(characterSchema.properties)),
    "character schema payload missing expected schema fields"
  );
  checks.push("character schema");

  const csrf = await getJson(`${baseUrl}/character-api/auth/csrf`, 200);
  expect(typeof csrf.csrfToken === "string", "csrfToken missing/invalid");
  expect(typeof csrf.authenticated === "boolean", "authenticated missing/invalid");
  checks.push("auth csrf");

  const obrMiss = await getJson(obrUrl, 200);
  expect(obrMiss.found === false, "obr miss response must include found:false");
  expect(obrMiss.sheet === null, "obr miss response must include sheet:null");
  checks.push("obr instance miss");

  console.log(
    `contract:smoke OK (${checks.length} checks) against ${baseUrl}: ${checks.join(", ")}`
  );
}

run().catch((error) => {
  console.error(`contract:smoke ERROR: ${error.message || String(error)}`);
  process.exit(1);
});
