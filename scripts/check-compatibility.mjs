#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const manifestsDir = path.join(repoRoot, "compatibility", "manifests");
const matrixPath = path.join(repoRoot, "compatibility", "matrix.json");

function fail(errors) {
  for (const error of errors) {
    console.error(`compat:check ERROR: ${error}`);
  }
  process.exit(1);
}

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

if (!fs.existsSync(manifestsDir)) {
  fail([`Missing manifests directory: ${manifestsDir}`]);
}

if (!fs.existsSync(matrixPath)) {
  fail([`Missing compatibility matrix: ${matrixPath}`]);
}

const manifestFiles = fs
  .readdirSync(manifestsDir)
  .filter((name) => name.endsWith(".json"))
  .sort();

if (manifestFiles.length === 0) {
  fail([`No manifest files found in ${manifestsDir}`]);
}

const manifests = new Map();
for (const file of manifestFiles) {
  const fullPath = path.join(manifestsDir, file);
  let data;
  try {
    data = readJson(fullPath);
  } catch (error) {
    errors.push(`Invalid JSON in ${fullPath}: ${String(error.message || error)}`);
    continue;
  }

  if (!isObject(data)) {
    errors.push(`${file} must contain a JSON object`);
    continue;
  }
  if (typeof data.repo !== "string" || data.repo.trim() === "") {
    errors.push(`${file} is missing non-empty string field: repo`);
    continue;
  }
  if (typeof data.version !== "string" || parseSemver(data.version) === null) {
    errors.push(`${file} has invalid version; expected semver x.y.z`);
  }
  if (!isObject(data.exports)) {
    errors.push(`${file} is missing object field: exports`);
  } else {
    for (const [key, value] of Object.entries(data.exports)) {
      if (typeof value !== "string" || parseSemver(value) === null) {
        errors.push(`${file} export ${key} must be semver x.y.z`);
      }
    }
  }
  if (!Array.isArray(data.dependsOn)) {
    errors.push(`${file} is missing array field: dependsOn`);
  }
  if (manifests.has(data.repo)) {
    errors.push(`Duplicate repo manifest for ${data.repo}`);
    continue;
  }
  manifests.set(data.repo, data);
}

for (const [repo, manifest] of manifests.entries()) {
  if (!Array.isArray(manifest.dependsOn)) continue;
  for (const dep of manifest.dependsOn) {
    if (!isObject(dep) || typeof dep.repo !== "string" || !isObject(dep.requires)) {
      errors.push(`${repo} has invalid dependsOn entry; expected { repo, requires }`);
      continue;
    }
    const depManifest = manifests.get(dep.repo);
    if (!depManifest) {
      errors.push(`${repo} depends on missing manifest repo ${dep.repo}`);
      continue;
    }
    for (const [key, range] of Object.entries(dep.requires)) {
      if (typeof range !== "string" || range.trim() === "") {
        errors.push(`${repo} has empty range for ${dep.repo}.${key}`);
        continue;
      }
      const exported = depManifest.exports?.[key];
      if (typeof exported !== "string") {
        errors.push(`${repo} requires ${dep.repo}.${key}, but ${dep.repo} does not export it`);
        continue;
      }
      if (!satisfies(exported, range)) {
        errors.push(
          `${repo} requires ${dep.repo}.${key} ${range}, but found ${exported}`
        );
      }
    }
  }
}

let matrix;
try {
  matrix = readJson(matrixPath);
} catch (error) {
  errors.push(`Invalid JSON in ${matrixPath}: ${String(error.message || error)}`);
}

if (isObject(matrix)) {
  if (typeof matrix.schemaVersion !== "number") {
    errors.push(`compatibility/matrix.json must include numeric schemaVersion`);
  }
  if (typeof matrix.activeRelease !== "string" || matrix.activeRelease.trim() === "") {
    errors.push(`compatibility/matrix.json must include non-empty activeRelease`);
  }
  if (!Array.isArray(matrix.releases) || matrix.releases.length === 0) {
    errors.push(`compatibility/matrix.json must include non-empty releases array`);
  } else {
    const active = matrix.releases.find((release) => release.id === matrix.activeRelease);
    if (!active) {
      errors.push(`activeRelease ${matrix.activeRelease} not found in releases`);
    } else {
      if (!isObject(active.versions)) {
        errors.push(`Active release must include versions object`);
      } else {
        for (const repo of manifests.keys()) {
          const declared = active.versions[repo];
          const actual = manifests.get(repo)?.version;
          if (typeof declared !== "string") {
            errors.push(`Active release missing version entry for ${repo}`);
            continue;
          }
          if (declared !== actual) {
            errors.push(
              `Active release version mismatch for ${repo}: matrix=${declared}, manifest=${actual}`
            );
          }
        }
      }
      if (!isObject(active.contracts)) {
        errors.push(`Active release must include contracts object`);
      } else {
        const requiredContracts = [
          "rules_contract",
          "calc_contract",
          "character_api_contract",
          "character_record_schema",
        ];
        for (const key of requiredContracts) {
          const value = active.contracts[key];
          if (typeof value !== "string" || parseSemver(value) === null) {
            errors.push(`Active release contract ${key} must be semver x.y.z`);
          }
        }
      }
    }
  }
}

if (errors.length > 0) {
  fail(errors);
}

console.log(
  `compat:check OK (${manifests.size} manifests, active release ${matrix.activeRelease})`
);
