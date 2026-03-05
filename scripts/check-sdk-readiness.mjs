#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const manifestsDir = path.join(repoRoot, "compatibility", "manifests");
const readinessPath = path.join(repoRoot, "compatibility", "sdk-readiness.json");

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function parseSemver(value) {
  const match = /^(\d+)\.(\d+)\.(\d+)(?:[-+][0-9A-Za-z.-]+)?$/.exec(value);
  if (!match) return null;
  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
  };
}

function compareSemver(a, b) {
  if (a.major !== b.major) return a.major - b.major;
  if (a.minor !== b.minor) return a.minor - b.minor;
  return a.patch - b.patch;
}

function satisfies(actual, range) {
  if (range === "*") return true;
  if (range.startsWith("^")) {
    const min = parseSemver(range.slice(1));
    const got = parseSemver(actual);
    if (!min || !got) return false;
    if (got.major !== min.major) return false;
    return compareSemver(got, min) >= 0;
  }
  const exact = parseSemver(range);
  if (exact) {
    const got = parseSemver(actual);
    if (!got) return false;
    return compareSemver(got, exact) === 0;
  }
  return actual === range;
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

const errors = [];
const warnings = [];

if (!fs.existsSync(readinessPath)) {
  console.error(`sdk:readiness ERROR: missing ${readinessPath}`);
  process.exit(1);
}

const readiness = readJson(readinessPath);
if (!isObject(readiness)) {
  console.error(`sdk:readiness ERROR: readiness config must be an object`);
  process.exit(1);
}

const targetSchema = readiness.targetCharacterRecordSchema;
if (typeof targetSchema !== "string" || parseSemver(targetSchema) === null) {
  errors.push(`targetCharacterRecordSchema must be semver x.y.z`);
}
if (!Array.isArray(readiness.repos) || readiness.repos.length === 0) {
  errors.push(`repos must be a non-empty array`);
}

const manifestMap = new Map();
if (fs.existsSync(manifestsDir)) {
  for (const file of fs.readdirSync(manifestsDir)) {
    if (!file.endsWith(".json")) continue;
    const data = readJson(path.join(manifestsDir, file));
    if (typeof data.repo === "string") {
      manifestMap.set(data.repo, data);
    }
  }
}

for (const entry of readiness.repos || []) {
  if (!isObject(entry) || typeof entry.repo !== "string") {
    errors.push(`invalid repo readiness entry (missing repo)`);
    continue;
  }
  const status = entry.status;
  if (!["pending", "in_progress", "complete"].includes(status)) {
    errors.push(`${entry.repo} has invalid status ${String(status)}`);
    continue;
  }

  const manifest = manifestMap.get(entry.repo);
  if (!manifest) {
    errors.push(`${entry.repo} has no compatibility manifest`);
    continue;
  }

  const sdkDep = (manifest.dependsOn || []).find((dep) => dep.repo === "whisperspace-sdk");
  if (!sdkDep || !isObject(sdkDep.requires)) {
    errors.push(`${entry.repo} must declare dependsOn whisperspace-sdk`);
    continue;
  }
  const schemaRange = sdkDep.requires.character_record_schema;
  if (typeof schemaRange !== "string" || schemaRange.trim() === "") {
    errors.push(`${entry.repo} must require whisperspace-sdk.character_record_schema`);
    continue;
  }
  if (!satisfies(targetSchema, schemaRange)) {
    errors.push(
      `${entry.repo} requires character_record_schema ${schemaRange}, which does not satisfy target ${targetSchema}`
    );
  }

  if (status === "complete" && entry.shimFree !== true) {
    errors.push(`${entry.repo} marked complete but shimFree is not true`);
  }
  if (status !== "complete" && entry.shimFree === true) {
    warnings.push(`${entry.repo} shimFree=true but status is ${status}`);
  }
}

if (warnings.length > 0) {
  for (const warning of warnings) {
    console.warn(`sdk:readiness WARN: ${warning}`);
  }
}

if (errors.length > 0) {
  for (const error of errors) {
    console.error(`sdk:readiness ERROR: ${error}`);
  }
  process.exit(1);
}

const counts = { pending: 0, in_progress: 0, complete: 0 };
for (const entry of readiness.repos || []) {
  if (counts[entry.status] !== undefined) counts[entry.status] += 1;
}

console.log(
  `sdk:readiness OK (target schema ${targetSchema}) complete=${counts.complete} in_progress=${counts.in_progress} pending=${counts.pending}`
);
