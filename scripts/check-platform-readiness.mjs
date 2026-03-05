#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const configPath = path.join(repoRoot, "compatibility", "platform-client-readiness.json");

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

if (!fs.existsSync(configPath)) {
  console.error(`platform:readiness ERROR: missing ${configPath}`);
  process.exit(1);
}

let cfg;
try {
  cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
} catch (error) {
  console.error(`platform:readiness ERROR: invalid JSON (${String(error.message || error)})`);
  process.exit(1);
}

const errors = [];
if (!isObject(cfg)) {
  errors.push("config must be object");
}
if (typeof cfg.targetPackage !== "string" || cfg.targetPackage.trim() === "") {
  errors.push("targetPackage must be non-empty string");
}
if (!Array.isArray(cfg.repos) || cfg.repos.length === 0) {
  errors.push("repos must be non-empty array");
}

const counts = { pending: 0, in_progress: 0, complete: 0 };
for (const entry of cfg.repos || []) {
  if (!isObject(entry) || typeof entry.repo !== "string") {
    errors.push("invalid repo entry");
    continue;
  }
  if (!["pending", "in_progress", "complete"].includes(entry.status)) {
    errors.push(`${entry.repo} invalid status ${String(entry.status)}`);
    continue;
  }
  counts[entry.status] += 1;
  if (entry.status === "complete" && entry.adopted !== true) {
    errors.push(`${entry.repo} marked complete but adopted is not true`);
  }
}

if (errors.length > 0) {
  for (const error of errors) {
    console.error(`platform:readiness ERROR: ${error}`);
  }
  process.exit(1);
}

console.log(
  `platform:readiness OK (${cfg.targetPackage}) complete=${counts.complete} in_progress=${counts.in_progress} pending=${counts.pending}`
);
